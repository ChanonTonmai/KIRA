#!/usr/bin/env python3

import sys
import os
import re
import glob

# Check and import required packages
try:
    import yaml
    import networkx as nx
    import matplotlib
    # Use Agg backend for headless environments
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import numpy as np
    from matplotlib.table import Table
except ImportError as e:
    print(f"Error: Required Python package not found: {e}")
    print("Please install the required packages using:")
    print("pip3 install pyyaml networkx matplotlib numpy")
    sys.exit(1)

def load_dfg(yaml_file):
    """Load and parse YAML file with error handling."""
    try:
        with open(yaml_file, 'r') as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        print(f"Error: YAML file not found: {yaml_file}")
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"Error parsing YAML file: {e}")
        sys.exit(1)

def create_dfg_graph(data):
    """Create a directed graph from DFG data with error handling."""
    try:
        G = nx.DiGraph()
        
        # Add nodes for each PE and their instructions
        for pe_assignment in data['scheduling']['pe_assignments']:
            pe_id = pe_assignment['pe_id']
            for idx, instr in enumerate(pe_assignment['instructions']):
                # Create a unique node ID combining PE ID and instruction index
                node_id = f"PE{pe_id}_{idx}_{instr['operation']}"
                
                # Add node with attributes
                G.add_node(node_id,
                          pe_id=pe_id,
                          instr_idx=idx,
                          operation=instr['operation'],
                          format=instr['format'],
                          attributes=instr)
        
        # Add edges based on data dependencies
        for pe_assignment in data['scheduling']['pe_assignments']:
            pe_id = pe_assignment['pe_id']
            instructions = pe_assignment['instructions']
            
            # Create edges between consecutive instructions in the same PE
            for i in range(len(instructions) - 1):
                src_node = f"PE{pe_id}_{i}_{instructions[i]['operation']}"
                dst_node = f"PE{pe_id}_{i+1}_{instructions[i+1]['operation']}"
                G.add_edge(src_node, dst_node)
        
        return G
    except KeyError as e:
        print(f"Error: Missing required field in YAML: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error creating graph: {e}")
        sys.exit(1)

def parse_assembly_file(file_path):
    """Parse assembly file to extract register values."""
    register_values = {
        'x18': None, 'x19': None, 'x20': None, 'x21': None,
        'x22': None, 'x23': None, 'x24': None, 'x25': None
    }
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            
            # Look for register initialization patterns
            # Pattern for lui instructions
            lui_pattern = r'lui\s+(x1[8-9]|x2[0-5]),\s*(-?\d+)'
            # Pattern for addi instructions
            addi_pattern = r'addi\s+(x1[8-9]|x2[0-5]),\s*(x1[8-9]|x2[0-5]),\s*(-?\d+)'
            # Pattern for li instructions
            li_pattern = r'li\s+(x1[8-9]|x2[0-5]),\s*(-?\d+)'
            # Pattern for la instructions
            la_pattern = r'la\s+(x1[8-9]|x2[0-5]),\s*(-?\d+)'
            
            # Find all matches
            lui_matches = re.finditer(lui_pattern, content)
            addi_matches = re.finditer(addi_pattern, content)
            li_matches = re.finditer(li_pattern, content)
            la_matches = re.finditer(la_pattern, content)
            
            # Process lui instructions first
            for match in lui_matches:
                reg, value = match.groups()
                register_values[reg] = int(value) << 12
                
            # Process addi instructions
            for match in addi_matches:
                reg, _, value = match.groups()
                if register_values[reg] is not None:
                    register_values[reg] += int(value)
                else:
                    register_values[reg] = int(value)
            
            # Process li and la instructions
            for match in list(li_matches) + list(la_matches):
                reg, value = match.groups()
                register_values[reg] = int(value)
                
    except FileNotFoundError:
        print(f"Warning: Assembly file not found: {file_path}")
    except Exception as e:
        print(f"Error parsing assembly file {file_path}: {e}")
    
    return register_values

def get_pe_register_values(output_dir):
    """Get register values for all PEs from their assembly files."""
    pe_values = {}
    
    # Look for PE assembly files in the output directory
    assembly_files = glob.glob(os.path.join(output_dir, "pe*_assembly.s"))
    
    for file_path in assembly_files:
        # Extract PE number from filename
        pe_match = re.search(r'pe(\d+)_assembly\.s', os.path.basename(file_path))
        if pe_match:
            pe_num = int(pe_match.group(1))
            pe_values[pe_num] = parse_assembly_file(file_path)
    
    return pe_values

def create_memory_table(ax, data, output_dir):
    """Create a table showing memory configurations for each PE."""
    try:
        # Get PE register values from assembly files
        pe_values = get_pe_register_values(output_dir)
        
        # Get total PEs from hardware config
        total_pes = data['hardware_config']['total_pes']
        
        # Create headers
        headers = ['Register'] + [f'PE{i}' for i in range(total_pes)]
        
        # Create table data
        table_data = []
        registers = ['x18', 'x19', 'x20', 'x21', 'x22', 'x23', 'x24', 'x25']
        
        # Get memory configuration from YAML
        mem_config = data.get('mem_config', {})
        mem_offsets = data.get('hardware_config', {}).get('psrf_mem_offset', {})
        
        # Calculate maximum content length for each column
        max_lengths = [len('Register')]  # Start with header length
        for pe in range(total_pes):
            max_len = len(f'PE{pe}')
            for reg in registers:
                if pe in pe_values and pe_values[pe][reg] is not None:
                    value = pe_values[pe][reg]
                    max_len = max(max_len, len(str(value)))
            max_lengths.append(max_len)
        
        # Calculate total width needed
        total_width = sum(max_lengths)
        
        # Calculate column widths as proportions of total width
        col_widths = [width/total_width for width in max_lengths]
        
        for reg in registers:
            row = [reg]
            # Add values for each PE
            for pe in range(total_pes):
                if pe in pe_values and pe_values[pe][reg] is not None:
                    value = pe_values[pe][reg]
                    cell_value = f"{value}"
                    row.append(cell_value)
                else:
                    row.append('null')
            table_data.append(row)
        
        # Create table with dynamic column widths
        table = ax.table(cellText=table_data,
                        colLabels=headers,
                        cellLoc='center',
                        loc='center',
                        colWidths=col_widths)
        
        # Style the table
        table.auto_set_font_size(False)
        table.set_fontsize(8)
        table.scale(1, 2)  # Increased vertical scaling for better readability
        
        # Style header and cells
        for (row, col), cell in table.get_celld().items():
            if row == 0:  # Header row
                cell.set_facecolor('#404040')
                cell.set_text_props(color='white', weight='bold')
            else:
                # Color cells based on whether they have values
                if table_data[row-1][col] != 'null':
                    cell.set_facecolor('#e6ffe6')  # Light green for cells with values
                else:
                    cell.set_facecolor('#ffe6e6')  # Light red for null cells
                cell.set_edgecolor('black')
                cell.set_linewidth(0.5)
        
        # Add title to the table
        ax.set_title('Register Values (x18-x25) for Each PE', pad=20, fontsize=12, fontweight='bold')
        
        return table
    except Exception as e:
        print(f"Error creating memory table: {e}")
        return None

def visualize_dfg(yaml_file, output_file, output_dir):
    """Generate visualization of the DFG with error handling."""
    try:
        # Load and process DFG
        data = load_dfg(yaml_file)
        G = create_dfg_graph(data)
        
        # Create figure with larger size
        plt.figure(figsize=(15, 25))
        
        # Create subplots for table and graph
        gs = plt.GridSpec(2, 1, height_ratios=[0.8, 4])
        ax_table = plt.subplot(gs[0])
        ax_graph = plt.subplot(gs[1])
        
        # Create memory table with actual PE values
        create_memory_table(ax_table, data, output_dir)
        ax_table.axis('off')
        
        # Create position layout based on PE ID and instruction order
        pos = {}
        max_pe = max([int(node.split('PE')[1].split('_')[0]) for node in G.nodes()])
        
        # Calculate maximum number of instructions per PE
        max_instr_per_pe = {}
        for node in G.nodes():
            pe_id = int(node.split('PE')[1].split('_')[0])
            instr_idx = int(node.split('_')[1])
            max_instr_per_pe[pe_id] = max(max_instr_per_pe.get(pe_id, 0), instr_idx)
        
        # Position nodes with more vertical space but minimal horizontal space
        vertical_spacing = 2.5
        horizontal_spacing = 0.8
        for node in G.nodes():
            pe_id = int(node.split('PE')[1].split('_')[0])
            instr_idx = int(node.split('_')[1])
            pos[node] = (pe_id * horizontal_spacing, -instr_idx * vertical_spacing)
        
        # Draw the graph with larger nodes but without labels
        nx.draw(G, pos, 
                with_labels=False,  # Don't draw labels inside nodes
                node_color='lightblue',
                node_size=4000,
                font_size=10,
                font_weight='bold',
                arrows=True,
                arrowsize=30,
                ax=ax_graph)
        
        # Add node labels with operation and format
        labels = {}
        label_pos = {}  # Position for labels
        for node in G.nodes():
            op = G.nodes[node]['operation']
            fmt = G.nodes[node]['format']
            pe_id = int(node.split('PE')[1].split('_')[0])
            instr_idx = node.split('_')[1]
            
            # Format the label
            label = f"Operation: {op}\n" \
                   f"Step: {instr_idx}"
            
            # Add additional attributes if they exist
            attrs = G.nodes[node]['attributes']
            if 'loop_id' in attrs:
                label += f"\nLoop: {attrs['loop_id']}"
            if 'iterations' in attrs:
                label += f"\nIter: {attrs['iterations']}"
            if 'pc_start' in attrs:
                label += f"\nPC: {attrs['pc_start']}-{attrs['pc_stop']}"
            
            labels[node] = label
            
            # Position label to the right of the node
            x, y = pos[node]
            label_pos[node] = (x + 0, y)  # Offset to the right
        
        # Draw labels separately
        nx.draw_networkx_labels(G, label_pos, labels, font_size=10, font_family='monospace', ax=ax_graph)
        
        # Add PE markers
        for pe in range(max_pe + 1):
            ax_graph.axvline(x=pe * horizontal_spacing, color='gray', linestyle='--', alpha=0.3)
            ax_graph.text(pe * horizontal_spacing, 1, f"PE {pe}", 
                    ha='center', fontsize=12, fontweight='bold')
        
        # Add title and save
        plt.suptitle(f"Data Flow Graph: {os.path.basename(yaml_file)}", fontsize=16, y=0.95)
        plt.tight_layout()
        
        # Ensure output directory exists
        os.makedirs(os.path.dirname(output_file) or '.', exist_ok=True)
        plt.savefig(output_file, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"Successfully generated visualization: {output_file}")
        
    except Exception as e:
        print(f"Error generating visualization: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python visualize_dfg.py <input_yaml> <output_png> <output_dir>")
        print("Example: python visualize_dfg.py dfg.yaml output.png build/")
        sys.exit(1)
    
    visualize_dfg(sys.argv[1], sys.argv[2], sys.argv[3]) 