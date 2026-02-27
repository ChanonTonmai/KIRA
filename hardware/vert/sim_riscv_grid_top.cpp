// ============================================================================
// Copyright © 2011-2026 Université Bretagne Sud
// 4 Rue Jean Zay, 56100 Lorient, France.
//
// Project Name:   KIRA
// Design Name:    sim_riscv_grid_top
// Module Name:    sim_riscv_grid_top
// File Name:      sim_riscv_grid_top.cpp
// Create Date:    27/02/2026
// Engineer:       Chanon Khongprasongsiri
// Language:       C++
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Brief     : C++ simulation wrapper for the Verilated `Vriscv_grid_top` DUT.
//             - Parses command line arguments to select workload / configuration.
//             - Initializes TCDM and instruction memories from software outputs.
//             - Runs the cycle-accurate simulation and optional VCD tracing.
//             - Dumps result memories, compares against golden outputs, and
//               emits timing / conflict statistics reports.
//
// Arguments :
//   argv[1] - Folder name or path to software/output/<folder>/combined_memory.mem
//   argv[2] - Grid division factor (`grid_div`)
//   argv[3] - Operation type string (e.g. "conv", "gemm", "2mm", "relu", etc.)
//   argv[4] - TCDM arbitration policy (0 = round-robin, 1 = priority-min)
//
// Notes     :
//   - This file is intended to be used with Verilator-generated models.
//   - Waveform dumping is conditionally enabled to keep VCD size manageable.
//   - Report files are written under `./rpt`, `./rpt_tc`, and `./rpt_fc`.
// ============================================================================

#include <verilated.h>
#include <verilated_vcd_c.h>
#include <stdlib.h>
#include <iostream>
#include <iostream>
#include <fstream>   // For std::ifstream
#include <sstream>   // For std::istringstream
#include <bitset>    // For std::bitset
#include <string>    // For std::string
#include <algorithm> // For std::remove
#include <regex>
#include <vector>
#include <array>
#include "Vriscv_grid_top.h"  // The Verilated model header


// Clock period in simulation (in ns) 
// 100000/2-10 //
#define CLOCK_PERIOD_NS 10
#define SIM_TIME_LIMIT  99999999999-1
#define RELU_SIZE 14400

int period_debug; 

vluint64_t load_inst_time = 0; 
vluint64_t load_data_time = 0; 
vluint64_t load_data_read_time = 0; 
vluint64_t preload_time = 0; 

struct SimCon {
    Vriscv_grid_top *dut;         // Pointer to the DUT (Device Under Test)
    VerilatedVcdC *trace;         // Pointer to the trace object
    vluint64_t &sim_time;         // Reference to the simulation time

    // Constructor to initialize the struct
    SimCon(Vriscv_grid_top *dut, VerilatedVcdC *trace, vluint64_t &sim_time)
        : dut(dut), trace(trace), sim_time(sim_time) {}
};

bool compareResults(const std::vector<int32_t>& simResults, const std::string& goldenFile) {
    std::ifstream goldenFileStream(goldenFile);
    if (!goldenFileStream.is_open()) {
        std::cerr << "Error: Failed to open golden file " << goldenFile << std::endl;
        return false;
    }

    std::string line;
    size_t index = 0;
    bool match = true;

    while (std::getline(goldenFileStream, line)) {
        // Skip empty lines and comments
        if (line.empty() || (line.size() >= 2 && line.substr(0, 2) == "//")) {
            continue;
        }

        // If we've reached the end of simulation results but still have golden data
        if (index >= simResults.size()) {
            std::cout << "Error: Golden file has more data than simulation results" << std::endl;
            match = false;
            break;
        }

        try {
            int32_t goldenValue = std::stoi(line);
            if ((simResults[index]) != goldenValue) {
                std::cout << "Mismatch at index " << index 
                          << ": Sim=" << simResults[index] 
                          << ", Golden=" << goldenValue << std::endl;
                match = false;
            }
            index++;
        } catch (const std::exception& e) {
            std::cerr << "Error parsing line in golden file: " << line << std::endl;
            match = false;
            break;
        }
    }

    // Check if we have more simulation results than golden data
    if (index < simResults.size()) {
        std::cout << "Error: Simulation has more results than golden file" << std::endl;
        match = false;
    }

    goldenFileStream.close();
    return match;
}
// Helper function to toggle the clock
void toggleClock(SimCon &cont) {
    cont.dut->clk = 1;
    cont.dut->eval();
    if (cont.trace) cont.trace->dump(cont.sim_time);
    cont.sim_time++;

    cont.dut->clk = 0;
    cont.dut->eval();
    if (cont.trace) cont.trace->dump(cont.sim_time);
    cont.sim_time++;
}


void TCDM_write(SimCon &cont, uint32_t baseAddr, const std::string &dataFile, 
                int length, bool writeAsBytes = false, int num_pe = 16) {
    // Open the input file
    std::ifstream inFile(dataFile);
    if (!inFile.is_open()) {
        std::cerr << "Error: Failed to open file " << dataFile << " for reading" << std::endl;
        return;
    }

    int i = 0;
    int local_index = 0;
    int each_pe_need_data;
    std::string line;
    std::vector<int8_t> bytes;
    
    // Read all values and validate them if writing as bytes
    if (writeAsBytes) {
        while (i < length && std::getline(inFile, line)) {
            // Skip empty lines or comment lines
            if (line.empty() || (line.size() >= 2 && line.substr(0, 2) == "//")) {
                continue;
            }
            
            // Parse the integer from the line
            int data;
            try {
                data = std::stoi(line);
                // Validate byte range [-128, 127]
                if (data < -128 || data > 127) {
                    std::cerr << "Error: Value " << data << " at index " << i 
                              << " is outside valid byte range [-128, 127]" << std::endl;
                    inFile.close();
                    return;
                }
                bytes.push_back(static_cast<int8_t>(data));
                i++;
            } catch (const std::exception& e) {
                std::cerr << "Error: Failed to parse data at index " << i << std::endl;
                break;
            }
        }
        
        // Reset file position for processing
        inFile.close();
        i = 0;
        
        // Pack bytes into 32-bit words and write them
        while (i < bytes.size()) {
            uint32_t wordData = 0;
            int bytesInWord = 0;
            
            // Pack up to 4 bytes into a single 32-bit word (little-endian)
            for (int b = 0; b < 4 && (i + b) < bytes.size(); b++) {
                wordData |= (static_cast<uint32_t>(bytes[i + b]) & 0xFF) << (8 * b);
                bytesInWord++;
            }
            
            // Write the packed word to memory
            cont.dut->host_load_store_data_req = 1;
            cont.dut->host_load_store_req = 1;
            cont.dut->host_dmem_addr = (baseAddr + (i / 4)) * 4; // Align to word boundary
            cont.dut->host_dmem_din = wordData;
            
            // Debug output with address in both hex and decimal
            uint32_t addr = cont.dut->host_dmem_addr;
            // std::cout << "[debug:BYTE_WRITE] Address=0x" << std::hex << addr
            //           << " (" << std::dec << addr << ")"
            //           << " Data=0x" << std::hex << wordData << std::dec << " (";
            for (int b = 0; b < bytesInWord; b++) {
                std::cout << (b > 0 ? ", " : "") << static_cast<int>(bytes[i + b]);
            }
            std::cout << ")" << std::endl;
            
            // Toggle clock
            toggleClock(cont);
            load_data_time++;
            i += bytesInWord;
        }
    } else {
        // Original word-based write
        if (baseAddr < 524288/4 - 1) { // normal write to TCDM 
            while (i < length && std::getline(inFile, line)) {
                // Skip empty lines or comment lines
                if (line.empty() || (line.size() >= 2 && line.substr(0, 2) == "//")) {
                    continue;
                }
                
                // Parse the integer from the line
                int data;
                try {
                    data = std::stoi(line);
                } catch (const std::exception& e) {
                    std::cerr << "Error: Failed to parse data at index " << i << std::endl;
                    break;
                }

                // Set the signals for memory write
                cont.dut->host_load_store_data_req = 1;
                cont.dut->host_load_store_req = 1;
                cont.dut->host_dmem_addr = (baseAddr + i) * 4;
                cont.dut->host_dmem_din = data;
                
                // Debug output with address in both hex and decimal
                uint32_t addr = cont.dut->host_dmem_addr;
                std::cout << "[debug:WORD_WRITE] Address=0x" << std::hex << addr
                        << " (" << std::dec << addr << ")"
                        << " Data=" << data << std::endl;
                
                // Toggle clock
                toggleClock(cont);
                load_data_time++;
                i++;
            }
        } else {
            // write to local mem
            while (i < length && std::getline(inFile, line)) {
                // Skip empty lines or comment lines

                each_pe_need_data = length/num_pe; 

                std::cout << "each_pe_need_data: " << each_pe_need_data << std::endl;
                int current_tx_pe = 0;
                if (line.empty() || (line.size() >= 2 && line.substr(0, 2) == "//")) {
                    continue;
                }
                
                // Parse the integer from the line
                int data;
                try {
                    data = std::stoi(line);
                } catch (const std::exception& e) {
                    std::cerr << "Error: Failed to parse data at index " << i << std::endl;
                    break;
                }

                // Set the signals for memory write
                cont.dut->host_load_store_data_req = 1;
                cont.dut->host_load_store_req = 1;
                cont.dut->host_dmem_addr = (baseAddr + local_index + 256*current_tx_pe) * 4; // 256 is the size of local memory for each PE
                cont.dut->host_dmem_din = data;
                
                
                // if (local_index == each_pe_need_data) {
                //     local_index = 0;
                //     current_tx_pe++; 
                // }
                std::cout << "local_index: " << local_index << " current_tx_pe: " << current_tx_pe << std::endl;
                // Debug output with address in both hex and decimal
                uint32_t addr = cont.dut->host_dmem_addr;
                std::cout << "[debug:WORD_WRITE] Address=0x" << std::hex << addr
                        << " (" << std::dec << addr << ")"
                        << " Data=" << data << std::endl;
                
                // Toggle clock
                toggleClock(cont);
                load_data_time++;
                i++;
                local_index++; 
            }
        }
    }

    // Clean up - reset signals
    cont.dut->host_load_store_data_req = 0;
    cont.dut->host_load_store_req = 0;
    
    // Toggle clock one more time (for cleanup)
    toggleClock(cont);
    
    if (inFile.is_open()) {
        inFile.close();
    }
    
    std::cout << "TCDM write complete: " << i << (writeAsBytes ? " bytes" : " words") 
              << " written to memory" << std::endl;
}


std::vector<int32_t> TCDM_read(SimCon &cont, uint32_t baseAddr, const std::string &dataFile, int length, bool readAsBytes) {
    // Open the output file
    std::ofstream outFile(dataFile);
    if (!outFile.is_open()) {
        std::cerr << "Error: Failed to open file " << dataFile << " for writing" << std::endl;
        return {};
    }

    std::vector<int32_t> results;
    results.reserve(readAsBytes ? length * 4 : length);  // Pre-allocate

    // For each iteration, we read one 32-bit word from memory
    for (int i = 0; i < length; ++i) {
        // Prepare the address (word-aligned if we do "word" reads).
        // If your memory is strictly word-addressed, the address might be (baseAddr + i).
        // But traditionally, with a byte-addressed bus, you do (baseAddr + i*4) for each word.
        uint32_t currentAddress = (baseAddr + i) * 4;

        // Drive signals to request a 32-bit read at `currentAddress`.
        cont.dut->host_load_store_data_req = 1;
        cont.dut->host_load_store_req      = 0;  // 0 for load, 1 for store if you have that convention
        cont.dut->host_dmem_addr          = currentAddress;
        cont.dut->host_dmem_din           = 0;   // Not used for loads

        // Toggle clock to latch address/req signals
        toggleClock(cont);
        load_data_read_time++; 
        // The DUT should place valid data on host_dmem_out
        // Convert the 32-bit output to a signed integer
        int32_t wordVal = static_cast<int32_t>(cont.dut->host_dmem_out);

        if (!readAsBytes) {
            // WORD MODE:  push back the entire 32-bit word
            results.push_back(wordVal);
            outFile << wordVal << "\n";  // log the word
            // Debug print (optional)
            uint32_t addr = cont.dut->host_dmem_addr;
            std::cout << "[debug:WORD] Address=0x" << std::hex << addr
                      << " (" << std::dec << addr << ")"
                      << " Data=" << std::dec << wordVal
                      << std::endl;
        } else {
            // BYTE MODE: split the 32-bit word into four separate bytes
            // The order of extraction (lowest byte first, etc.) depends on endianness.
            // For example, if the data is little-endian, then:
            //   byte0 = wordVal[7:0]
            //   byte1 = wordVal[15:8]
            //   byte2 = wordVal[23:16]
            //   byte3 = wordVal[31:24]
            //
            // We'll do little-endian extraction below:
            for (int b = 0; b < 4; ++b) {
                // Extract byte and properly sign-extend it
                int8_t signedByte = static_cast<int8_t>((wordVal >> (8 * b)) & 0xFF);
                int32_t byteVal = signedByte;  // Implicit sign extension
                
                results.push_back(byteVal);

                // Log to file and output as signed value
                outFile << byteVal << "\n";
                uint32_t addr = cont.dut->host_dmem_addr;
                std::cout << "[debug:BYTE] Address=0x" << std::hex << addr
                          << " (" << std::dec << addr << ")"
                          << " ByteIndex=" << std::dec << b
                          << " Data=" << byteVal << " (signed)"
                          << std::endl;
            }
        }
    }

    outFile.close();
    return results;
}

void loadInstructions(SimCon &cont, const std::string& inputFile) {
    std::ifstream inFile(inputFile);
    std::cout << ">> inputFile: " << inputFile << std::endl;
    if (!inFile.is_open()) {
        std::cerr << "Error opening input file: " << inputFile << std::endl;
        return;
    }

    // Set the initial write enable signal
    cont.dut->imem_wea = 0xF;
    
    std::string line;
    int instructionCount = 0;
    
    while (std::getline(inFile, line)) {
        // Skip empty lines
        if (line.empty()) continue;
        
        // Skip comment lines (starting with '//')
        if (line.substr(0, 2) == "//") continue;

        // The format is "@HHHHHHHH HHHHHHHH" where the first part is the address
        // and the second part is the instruction data
        if (line[0] != '@') {
            std::cerr << "Invalid line format: " << line << std::endl;
            continue;
        }

        // Parse the line into address and data
        std::istringstream iss(line.substr(1)); // Skip the '@'
        std::string hexAddress, hexData;
        
        if (iss >> hexAddress >> hexData) {
            // Convert hex address to integer (only use the lower 14 bits)
            uint32_t address = std::stoul(hexAddress, nullptr, 16) & 0xFFFF; // 14 bits

            // Convert hex data to integer
            uint32_t data = std::stoul(hexData, nullptr, 16);

            // Assign values to 'dut' and call 'toggleClock'
            cont.dut->imem_addra = address;
            cont.dut->imem_dina = data;
            
            instructionCount++;

            // For debugging
            std::cout << "Loading instruction " << instructionCount << " - Address: 0x" << std::hex << address 
                      << " (bit 10: " << ((address & 0x400) ? "1" : "0") 
                      << ", PE: " << ((address >> 10) & 0xF) << ")"
                      << " Data: 0x" << data << std::dec << std::endl;

            toggleClock(cont);
            load_inst_time++; 
        } else {
            std::cerr << "Failed to parse line: " << line << std::endl;
        }
    }
    
    // Reset the write enable signal after loading
    cont.dut->imem_wea = 0x0;
    toggleClock(cont);
    
    std::cout << "Instruction loading complete. Loaded " << instructionCount << " instructions." << std::endl;
}

void generateReport(const std::string& folderName, vluint64_t sim_time, vluint64_t measure_time, 
                    bool resultsMatch, int grid_div, int N_R, int N_C, const uint32_t* dbg_mem_conflict,
                    vluint64_t load_inst_time, vluint64_t load_data_time, vluint64_t load_data_read_time, 
                    vluint64_t preload_time, int arb_policy, 
                    const uint32_t* dbg_ic, const uint32_t* dbg_ic_trap) {
    // Create rpt directory if it doesn't exist
    std::string rptDir = "./rpt";
    if (system(("mkdir -p " + rptDir).c_str()) != 0) {
        std::cerr << "Error: Failed to create report directory " << rptDir << std::endl;
        return;
    }

    std::string arb_policy_str = arb_policy ? "pm" : "rr";
    std::string reportFileName = rptDir + "/rpt_" + folderName  + "_" + arb_policy_str + ".txt";
    std::ofstream reportFile(reportFileName);
    
    if (!reportFile.is_open()) {
        std::cerr << "Error: Failed to create report file " << reportFileName << std::endl;
        return;
    }

    reportFile << "Simulation Report for " << folderName << "\n";
    // reportFile << "Operation type: " << operationType << "\n";
    reportFile << "========================================\n\n";
    
    reportFile << "Configuration:\n";
    reportFile << "N_R: " << N_R << "\n";
    reportFile << "N_C: " << N_C << "\n";
    reportFile << "Memory file: ../../software/output/" << folderName << "/combined_memory.mem\n";
    reportFile << "Grid division: " << grid_div << "\n";
    reportFile << "Arb policy: " << arb_policy_str << "\n\n";
    reportFile << "Timing Results:\n";
    reportFile << "Total simulation time: " << (sim_time/2) * CLOCK_PERIOD_NS << " ns\n";
    reportFile << "Execution Cycle: " << measure_time << " cycles\n";
    reportFile << "Load Instruction: " << load_inst_time << " cycles\n";
    reportFile << "Load Data: " << load_data_time << " cycles\n";
    reportFile << "Read Data: " << load_data_read_time << " cycles\n";
    reportFile << "Preload: " << preload_time << " cycles\n\n";


    reportFile << "Memory Conflict:\n";
    int max_mem_conflict = 0;
    for (int i = 0; i < N_R * N_C; i++) {
        reportFile << "PE " << i << ": " << dbg_mem_conflict[i] << "\n";
        if (dbg_mem_conflict[i] > max_mem_conflict) {
            max_mem_conflict = dbg_mem_conflict[i];
        }   
    }
    reportFile << "Max Memory Conflict: " << max_mem_conflict << "\n\n";

    reportFile << "IC per PE:\n";
    for (int i = 0; i < N_R * N_C; i++) {
        reportFile << "PE " << i << ": " << dbg_ic[i] << "\n";
    }

    reportFile << "\nIC_trap per PE:\n";
    for (int i = 0; i < N_R * N_C; i++) {
        reportFile << "PE " << i << ": " << dbg_ic_trap[i] << "\n";
    }
    
    reportFile << "Verification Results:\n";
    reportFile << "Results match golden output: " << (resultsMatch ? "Yes" : "No") << "\n";
    
    reportFile.close();
    
    std::cout << "Report generated: " << reportFileName << std::endl;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);

    if (argc < 5) {
        std::cerr << "Usage: " << argv[0] << " <folder_name> <grid_div> <operation_type> <arb_policy>" << std::endl;
        std::cerr << "Example: " << argv[0] << " output_cmsis_l1_8x4 16 conv 1" << std::endl;
        std::cerr << "Example: " << argv[0] << " output_cmsis_l1_8x4 16 gemm 0" << std::endl;
        std::cerr << "arb_policy: 0 --> Round Robin, 1 --> Priority min" << std::endl;
        return 1;
    }

    // Extract folder name from the full path
    std::string fullPath = argv[1];
    std::string folderName;
    std::string memoryPath_state2;
    
    // Find the last occurrence of '/'
    size_t lastSlash = fullPath.find_last_of('/');
    if (lastSlash != std::string::npos) {
        // Extract everything after the last '/'
        folderName = fullPath.substr(lastSlash + 1);
    } else {
        // If no '/' found, use the entire string
        folderName = fullPath;
    }

    // Remove any file extension if present
    size_t dotPos = folderName.find_last_of('.');
    if (dotPos != std::string::npos) {
        folderName = folderName.substr(0, dotPos);
    }

    int grid_div = std::stoi(argv[2]);  // Convert string to integer
    int arb_policy = std::stoi(argv[4]);  // Convert string to integer
    std::string operationType = argv[3]; // Get operation type
    
    std::regex pattern("(.*)_(\\d+)$");
    std::smatch matches;
    std::string base_name;
    std::string suffix;
    
    if (std::regex_match(folderName, matches, pattern)) {
        base_name = matches[1].str();
        suffix = "_" + matches[2].str();
        
        std::cout << "Original string: " << folderName << std::endl;
        std::cout << "Base name: " << base_name << std::endl;
        std::cout << "Suffix: " << suffix << std::endl;
    }

    std::string memoryPath = "../../software/output/" + folderName + "/combined_memory.mem";
    if (operationType == "2mm") {
        std::cout << ">> 2mm_1 get memory path" << std::endl;
        memoryPath_state2 = "../../software/output/" + base_name + "_2/combined_memory.mem";
    }
    std::cout << ">> memoryPath_state2: " << memoryPath_state2 << std::endl;


    // Initialize dut Verilog module
    Vriscv_grid_top* dut = new Vriscv_grid_top;
    vluint64_t sim_time = 0;
    vluint64_t measure_time = 0;

    std::vector<uint32_t> dataB;
    std::vector<uint32_t> dataA;
    std::vector<uint32_t> data_golden;
    bool readAsBytes = false; 

    // Enable waveform dump
    Verilated::traceEverOn(true);
    VerilatedVcdC *trace = nullptr;
    trace = new VerilatedVcdC;

    // If the simulation time is less than 100000, enable waveform dump. 
    // Else the waveform is too large to handle.
    if (SIM_TIME_LIMIT < 100000 || operationType == "others" || operationType == "relu") {
        dut->trace(trace, 1);
        trace->open("waveform2.vcd");
        std::cout << ">> waveform dump enabled" << std::endl;
    }
    // dut->trace(trace, 1);
    // trace->open("waveform.vcd");


    SimCon simcont(dut, trace, sim_time);
    // Reset logic
    dut->clk = 0;
    dut->rst = 1;
    dut->inst_en = 0;
    dut->preload = 0;
    dut->imem_dina = 0;
    dut->imem_wea = 0;
    dut->imem_addra = 0;
    dut->host_load_store_data_req = 0;
    dut->host_load_store_req = 0;
    dut->host_dmem_addr = 0;
    dut->host_dmem_din = 0;
    dut->grid_div = grid_div;
    dut->tcdm_arb_policy = arb_policy;
    dut->mode_select = 0; // 0 --> shared mode, 1 --> bypass mode
    int N_R = dut->dbg_nr;
    int N_C = dut->dbg_nc;
 

    // Hold reset for a few clock cycles
    for (int i = 0; i < 2; i++) {
        toggleClock(simcont);
    }
    dut->rst = 0;
    for (int i = 0; i < 2; i++) {
        toggleClock(simcont);
    }

    for (int i = 0; i < 5; i++) {
        toggleClock(simcont);
    }

    // 524288
    if (operationType == "conv") { // if conv, we need to change the ALU bit (ducktape 1)
        TCDM_write(simcont, 15000/4, "../../software/kernel/conv_int8/padded_input.txt", 36*36*3, false);
        TCDM_write(simcont, 84/4, "../../software/kernel/conv_int8/weights.txt", 5*5*3*32, false);
    } else if (operationType == "gemm" || operationType == "gemmadd64x64") {
        TCDM_write(simcont, 200/4, "../../software/kernel/gemm/ncubed/input_A.data", 4096, false, 16);
        TCDM_write(simcont, 20000/4, "../../software/kernel/gemm/ncubed/input_B.data", 4096, false, 16);
    } else if (operationType == "gemm32x32" || operationType == "gemmadd32x32") {
        //TCDM_write(simcont, 200/4, "../../software/kernel/gemm_32x32/ncubed/input_A.data", 1024, false);
        //TCDM_write(simcont, 20000/4, "../../software/kernel/gemm_32x32/ncubed/input_B.data", 1024, false);
        TCDM_write(simcont, 15000/4, "../../software/kernel/gemm_128x128/ncubed/input_B.data", 16384, false); 
        TCDM_write(simcont, 31384/4, "../../software/kernel/gemm_128x128/ncubed/input_B.data", 16384, false); 
    } else if (operationType == "gemm128x128") {
        TCDM_write(simcont, 200/4, "../../software/kernel/gemm_128x128/ncubed/input_A.data", 16384, false);
        TCDM_write(simcont, 70000/4, "../../software/kernel/gemm_128x128/ncubed/input_B.data", 16384, false); 
    } else if (operationType == "gemm_dup") {
        TCDM_write(simcont, 200/4, "../../software/kernel/gemm/ncubed/input_A.data", 4096, false);
        TCDM_write(simcont, 20000/4, "../../software/kernel/gemm/ncubed/input_B.data", 4096, false);

        TCDM_write(simcont, (100000+200)/4, "../../software/kernel/gemm/ncubed/input_A.data", 4096, false);
        TCDM_write(simcont, (100000+20000)/4, "../../software/kernel/gemm/ncubed/input_B.data", 4096, false);
    } else if (operationType == "instTest") {
        // do nothing
    } else if (operationType == "2mm") {
        TCDM_write(simcont, 200  /4, "../../software/kernel/2mm/ncubed/input_fxp_matrix_1.data", 4096, false);
        TCDM_write(simcont, 20000/4, "../../software/kernel/2mm/ncubed/input_fxp_matrix_2.data", 4096, false);
        TCDM_write(simcont, 40000/4, "../../software/kernel/2mm/ncubed/input_fxp_matrix_3.data", 4096, false);
    } else if (operationType == "relu") {
        TCDM_write(simcont, 15000/4, "../../software/kernel/conv_int8/output.txt", RELU_SIZE, false);
    } else if (operationType == "others") {
        // do nothing 
        TCDM_write(simcont, 15000/4, "../../software/kernel/gemm_128x128/ncubed/input_B.data", 16384, false); 
        TCDM_write(simcont, 31384/4, "../../software/kernel/gemm_128x128/ncubed/input_B.data", 16384, false); 
        std::cout << ">> others perform" << std::endl;


    } else if (operationType == "resnet_conv1") {
        TCDM_write(simcont, 45000/4, "../../software/kernel/image_pad/padded_output.txt", 38*38*3, false); // input 
        TCDM_write(simcont, 84/4,    "../../software/kernel/data/resnet18_prunned_weights50/conv1.weight_raw_fxp.txt", 64*3*49, false); // filter
    } else {
        std::cerr << "Error: Invalid operation type. Must be either 'conv' or 'gemm'" << std::endl;
        return 1;
    }
    toggleClock(simcont);
    toggleClock(simcont);

    loadInstructions(simcont, memoryPath);


    toggleClock(simcont);
    toggleClock(simcont);


    // Preload logic
    dut->preload = 1;
    toggleClock(simcont);
    toggleClock(simcont);
    dut->preload = 0;

    // Enable execution
    dut->inst_en = 1;
    toggleClock(simcont);
    toggleClock(simcont);

    std::cout << ">> preload perform" << std::endl; 
     
    while (!dut->finish && sim_time < SIM_TIME_LIMIT) {
        toggleClock(simcont);
        preload_time++;
    }

    dut->inst_en = 0;

    toggleClock(simcont);
    toggleClock(simcont);
    dut->rst = 1; 
    toggleClock(simcont);
    dut->inst_en = 1;
    toggleClock(simcont);
    dut->rst = 0; 

    std::cout << ">> start simulation" << std::endl; 
    period_debug = 0;
    measure_time = measure_time+5; 

    // Vector to store temporal memory conflict values
    std::vector<uint8_t> temporal_conflicts;
    std::vector<uint64_t> finish_conflicts;
    temporal_conflicts.reserve(5000000); // Pre-allocate space for efficiency
    finish_conflicts.reserve(5000000);

    int jjj = 0 ;
    while (!dut->finish && sim_time < SIM_TIME_LIMIT) {
        toggleClock(simcont);
        period_debug++;
        measure_time++; 
        
        // Capture the temporal memory conflict value
        temporal_conflicts.push_back(dut->dbg_mc_temporal_out);
        finish_conflicts.push_back(dut->dbg_finish);
        if (period_debug == 200000) {
            std::cout << ">> 2ms reached : " << jjj << std::endl;
            period_debug = 0;
            jjj++;   
        }

        // if (measure_time > 200000) {
        //     dut->tcdm_arb_policy = ~arb_policy;
        //     if (measure_time == 200000) {
        //         std::cout << ">> change arb policy" << std::endl;
        //     }       
        // }
    }




    dut->inst_en = 0;
    dut->rst = 1;
    toggleClock(simcont);
    dut->rst = 0;

    // Perform second state of 2mm
    // Data is already stored in TCDM.
    // Everything is the same as the first state.
    if (operationType == "2mm") {
        loadInstructions(simcont, memoryPath_state2);

        toggleClock(simcont);
        toggleClock(simcont);

        // Preload logic
        dut->preload = 1;
        toggleClock(simcont);
        toggleClock(simcont);
        dut->preload = 0;

        // Enable execution
        dut->inst_en = 1;
        toggleClock(simcont);
        toggleClock(simcont);

        std::cout << ">> preload perform" << std::endl; 
        
        while (!dut->finish && sim_time < SIM_TIME_LIMIT) {
            toggleClock(simcont);
            measure_time++;
        }

        dut->inst_en = 0;

        toggleClock(simcont);
        toggleClock(simcont);
        dut->rst = 1; 
        toggleClock(simcont);
        dut->inst_en = 1;
        toggleClock(simcont);
        dut->rst = 0; 

        std::cout << ">> start simulation" << std::endl; 
        period_debug = 0;
        measure_time = measure_time+5; 
        while (!dut->finish && sim_time < SIM_TIME_LIMIT) {
            toggleClock(simcont);
            period_debug++;
            measure_time++; 
            
            // Capture the temporal memory conflict value
            temporal_conflicts.push_back(dut->dbg_mc_temporal_out);
            finish_conflicts.push_back(dut->dbg_finish);
            if (period_debug == 200000) {
                std::cout << ">> 2ms reached" << std::endl;
                period_debug = 0;   
            }

        }


        dut->inst_en = 0;
        dut->rst = 1;
        toggleClock(simcont);
        dut->rst = 0;
    }   


    // Write temporal conflicts to a file
    std::string arb_policy_str = arb_policy ? "pm" : "rr";
    std::string temporal_filename = "./rpt_tc/t_" + folderName + "_" + arb_policy_str + ".txt";
    std::ofstream conflict_file(temporal_filename);
    if (conflict_file.is_open()) {
        for (size_t i = 0; i < measure_time; i++) {
            conflict_file << "Cycle " << i << ": " << static_cast<int>(temporal_conflicts[i]) << "\n";
        }
        conflict_file.close();
        std::cout << "Temporal memory conflicts saved to " << temporal_filename << std::endl;
    } else {
        std::cerr << "Failed to open " << temporal_filename << " for writing" << std::endl;
    }

    // Write finish conflicts to a file
    std::string finish_filename = "./rpt_fc/f_" + folderName + "_" + arb_policy_str + ".txt";
    std::ofstream finish_file(finish_filename);
    if (finish_file.is_open()) {    
        for (size_t i = 0; i < measure_time; i++) {
            finish_file << "Cycle " << i << ": " << static_cast<uint64_t>(finish_conflicts[i]) << "\n";
        }
        finish_file.close();
        std::cout << "Finish conflicts saved to " << finish_filename << std::endl;
    } else {
        std::cerr << "Failed to open " << finish_filename << " for writing" << std::endl;
    }


    uint32_t baseAddress; 
    std::vector<int32_t> byteData;
    int length;
    std::string outFileBytes = "mem_dump_bytes.txt"; 

    if (operationType == "conv") {
        baseAddress = 44000/4;    // The starting address from which to read
        length = 32*32*32/1;         // N
        readAsBytes = false; 
        std::cout << "\nReading as bytes...\n";
        byteData = TCDM_read(simcont, baseAddress, outFileBytes, length, readAsBytes);

        std::cout << "Read " << byteData.size() 
                << " bytes (technically stored in int32_t) from 0x" << std::hex << baseAddress 
                << ". They are also logged in " << outFileBytes << std::dec << std::endl;
    
    } else if (operationType == "resnet_conv1") {
        baseAddress = (94000)/4;    // The starting address from which to read
        length = 65536;         // N
        readAsBytes = false; 
        std::cout << "\nReading as bytes...\n";
        byteData = TCDM_read(simcont, baseAddress, outFileBytes, length, readAsBytes);

        std::cout << "Read " << byteData.size() 
                << " bytes (technically stored in int32_t) from 0x" << std::hex << baseAddress 
                << ". They are also logged in " << outFileBytes << std::dec << std::endl;

    } else if (operationType == "gemm" || operationType == "gemmadd64x64") {   
        baseAddress = (40004)/4;    // The starting address from which to read
        length = 4096;         // N
        readAsBytes = false; 
        std::cout << "\nReading as bytes...\n";
        byteData = TCDM_read(simcont, baseAddress, outFileBytes, length, readAsBytes);

        std::cout << "Read " << byteData.size() 
                << " bytes (technically stored in int32_t) from 0x" << std::hex << baseAddress 
                << ". They are also logged in " << outFileBytes << std::dec << std::endl;

    } else if (operationType == "gemm32x32" || operationType == "gemmadd32x32") {   
        baseAddress = (90000)/4;    // The starting address from which to read
        length = 8192;         // N
        readAsBytes = false; 
        std::cout << "\nReading as bytes...\n";
        byteData = TCDM_read(simcont, baseAddress, outFileBytes, length, readAsBytes);

        std::cout << "Read " << byteData.size() 
                << " bytes (technically stored in int32_t) from 0x" << std::hex << baseAddress 
                << ". They are also logged in " << outFileBytes << std::dec << std::endl;

    } else if (operationType == "gemm128x128") {
        baseAddress = (150004)/4;    // The starting address from which to read
        length = 16384;         // N
        readAsBytes = false; 
        std::cout << "\nReading as bytes...\n";
        byteData = TCDM_read(simcont, baseAddress, outFileBytes, length, readAsBytes);

    } else if (operationType == "gemm_dup") {   
        baseAddress = (40004)/4;    // The starting address from which to read
        length = 4096/2;         // N
        readAsBytes = false; 
        std::cout << "\nReading as bytes...\n";
        byteData = TCDM_read(simcont, baseAddress, outFileBytes, length, readAsBytes);


        baseAddress = (148196)/4;    // The starting address from which to read
        length = 4096/2;         // N
        readAsBytes = false; 
        std::cout << "\nReading as bytes...\n";
        std::vector<int32_t> tempData = TCDM_read(simcont, baseAddress, outFileBytes, length, readAsBytes);

        byteData.insert(byteData.end(), tempData.begin(), tempData.end());

        std::cout << "Read " << byteData.size() 
                << " bytes (technically stored in int32_t) from 0x" << std::hex << baseAddress 
                << ". They are also logged in " << outFileBytes << std::dec << std::endl;

    } else if (operationType == "instTest") {
        baseAddress = (404)/4;    // The starting address from which to read
        length = 25;         // N
        readAsBytes = false; 
        std::cout << "\nReading as bytes...\n";
        byteData = TCDM_read(simcont, baseAddress, outFileBytes, length, readAsBytes);

        std::cout << "Read " << byteData.size() 
                << " bytes (technically stored in int32_t) from 0x" << std::hex << baseAddress 
                << ". They are also logged in " << outFileBytes << std::dec << std::endl;

    } else if (operationType == "2mm") {
        baseAddress = (80000)/4;    // The starting address from which to read
        length = 4096;         // N
        readAsBytes = false; 
        std::cout << "\nReading as bytes...\n";
        byteData = TCDM_read(simcont, baseAddress, outFileBytes, length, readAsBytes); 

    } else if (operationType == "relu") {
        baseAddress = (84)/4;    // The starting address from which to read
        length = RELU_SIZE;         // N
        readAsBytes = false; 
        std::cout << "\nReading as bytes...\n";
        byteData = TCDM_read(simcont, baseAddress, outFileBytes, length, readAsBytes); 

    } else if (operationType == "others") {
        // do nothing 
        baseAddress = (90000)/4;    // The starting address from which to read
        length = 8192;         // N
        readAsBytes = false; 
        std::cout << "\nReading as bytes...\n";
        byteData = TCDM_read(simcont, baseAddress, outFileBytes, length, readAsBytes);

        std::cout << "Read " << byteData.size() 
                << " bytes (technically stored in int32_t) from 0x" << std::hex << baseAddress 
                << ". They are also logged in " << outFileBytes << std::dec << std::endl;

        std::cout << ">> others perform" << std::endl;
    } else if (operationType == "resnet_conv1") {
        baseAddress = 94000 / 4;
        length = (64 * 32 * 32 );
        readAsBytes = false;
        byteData = TCDM_read(simcont, baseAddress, outFileBytes, length, readAsBytes);
        std::cout << "Read " << byteData.size() 
                << " bytes (technically stored in int32_t) from 0x" << std::hex << baseAddress 
                << ". They are also logged in " << outFileBytes << std::dec << std::endl;


    } else {
        std::cerr << "Error: Invalid operation type. Must be either 'conv' or 'gemm'" << std::endl;
        return 1;   
    }

    // Simulation cleanup
    dut->final();
    if (trace) {
        trace->close();
        delete trace;
    }

    bool resultsMatch;
    resultsMatch = true;
    if (operationType == "conv") {
        std::string goldenFile = "../../software/kernel/conv_int8/output.txt";
        resultsMatch = compareResults(byteData, goldenFile);
    } else if (operationType == "gemm" || operationType == "gemm_dup" ) {
        std::string goldenFile = "../../software/kernel/gemm/ncubed/output_raw.data";
        resultsMatch = compareResults(byteData, goldenFile);
    } else if (operationType == "gemm32x32") {
        std::string goldenFile = "../../software/kernel/gemm_32x32/ncubed/output_raw.data";
        resultsMatch = compareResults(byteData, goldenFile);
    } else if (operationType == "gemm128x128") {
        std::string goldenFile = "../../software/kernel/gemm_128x128/ncubed/output_raw.data";
        resultsMatch = compareResults(byteData, goldenFile);
    } else if (operationType == "instTest") {
        int32_t golden_data[25] = {
            -100, 200, 100, -300, -25600, 1, 0, -172, -36, 136, 16777215, -1, -104857600, 4095, -1, -1, 0, 0, 164, -68, -232, 0, 0, 0, 0
        };
        for (int i = 0; i < 25; i++) {
            if (byteData[i] != golden_data[i]) {
                std::cout << "byteData[" << i << "] = " << byteData[i] << " != " << golden_data[i] << std::endl;
                resultsMatch = false;
            }
        }
        std::cout << ">> instTest perform" << std::endl;
    } else if (operationType == "2mm") {
        std::string goldenFile = "../../software/kernel/2mm/ncubed/output_raw.data";
        resultsMatch = compareResults(byteData, goldenFile);
    } else if (operationType == "others" || operationType == "gemmadd32x32" || 
        operationType == "gemmadd64x64" || operationType == "resnet_conv1") {
        // do nothing 
        std::cout << ">> others perform" << std::endl;
    } else if (operationType == "relu") {
        std::string goldenFile = "../../software/kernel/relu/output.txt";
        //resultsMatch = compareResults(byteData, goldenFile);
    } else if (operationType == "resnet_conv1") {
        std::string goldenFile = "../../software/kernel/resnet_conv1/ncubed/output_raw.data";
        resultsMatch = false;
        std::cout << ">> resnet_conv1 perform" << std::endl;
        // resultsMatch = compareResults(byteData, goldenFile);
    } else {
        std::cerr << "Error: Invalid operation type. Must be either 'conv' or 'gemm'" << std::endl;
        // return 1;
    }   

    if (resultsMatch) {
        std::cout << "Simulation results match golden output!" << std::endl;
    } else {
        std::cout << "Simulation results do not match golden output!" << std::endl;
    }
    int cluster_value = 0; 
    generateReport(folderName, sim_time, measure_time, resultsMatch, grid_div, dut->dbg_nr, dut->dbg_nc, dut->dbg_mem_conflict, 
        load_inst_time, load_data_time, load_data_read_time, preload_time, arb_policy, dut->dbg_ic, dut->dbg_ic_trap);

    delete dut;
    std::cout << "Simulation finished at time: " << (sim_time/2) * CLOCK_PERIOD_NS << " ns" << std::endl;
    std::cout << "Measure at time: " << (measure_time) * CLOCK_PERIOD_NS << " ns" << std::endl;
    return 0;
}
