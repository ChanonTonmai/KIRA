#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <fxp/fxp.h>
#include <fxp/fxp_util.h>
#include "gemm.h"

#define MAX_LINE_LENGTH 16358
#define MATRIX_SIZE 64  // Assuming 32x32 matrices based on the file size

// Function to count non-empty lines in a file
int count_non_empty_lines(FILE *file) {
    int count = 0;
    char line[MAX_LINE_LENGTH];
    while (fgets(line, MAX_LINE_LENGTH, file) != NULL) {
        // Skip empty lines and comments
        if (strlen(line) > 1 && line[0] != '%') {
            count++;
        }
    }
    rewind(file);  // Reset file pointer to beginning
    return count;
}

int main() {
    FILE *input_file, *output_file, *check_file, *input_fxp_file, *output_file_raw;
    char line[MAX_LINE_LENGTH];
    int matrix_count = 0;
    int row = 0, col = 0;
    
    // Open the input file
    input_file = fopen("input.data", "r");
    if (input_file == NULL) {
        printf("Error: Could not open input.data\n");
        return 1;
    }

    input_fxp_file = fopen("input_fxp.data", "w");
    if (input_fxp_file == NULL) {
        printf("Error: Could not create input_fxp.data\n");
        return 1;
    }
    
    // Create arrays to store the matrices
    TYPE matrix_a[N];
    TYPE matrix_b[N];
    TYPE result[N];
    
    // Initialize matrices with fixed-point numbers
    for (int i = 0; i < N; i++) {
        matrix_a[i] = fxp_from_real(0.0, 16, 16, true);
        matrix_b[i] = fxp_from_real(0.0, 16, 16, true);
        result[i]   = fxp_from_real(0.0, 16, 16, true);
    }
    
    // Read the file line by line
    while (fgets(line, MAX_LINE_LENGTH, input_file) != NULL) {
        // Skip empty lines and comments
        if (strlen(line) <= 1 || line[0] == '%') {
            continue;
        }
        
        // Convert the line to a double and store in the appropriate matrix
        double value = atof(line);
        if (matrix_count == 0) {
            // First matrix (A)
            matrix_a[row * COL_SIZE + col] = fxp_from_real(value, 16, 16, true);
        } else {
            // Second matrix (B)
            matrix_b[row * COL_SIZE + col] = fxp_from_real(value, 16, 16, true);
        }

        fprintf(input_fxp_file, "%d\n", fxp_get_raw_value(fxp_from_real(value, 16, 16, true)));
        // Update indices
        col++;
        if (col >= COL_SIZE) {
            col = 0;
            row++;
            if (row >= ROW_SIZE) {
                row = 0;
                matrix_count++;
                if (matrix_count >= 2) {
                    break;  // We've read both matrices
                }
            }
        }

        
    }


    
    fclose(input_file);
    




    // Perform matrix multiplication
    printf("Performing matrix multiplication...\n");
    gemm(matrix_a, matrix_b, result);
    printf("Multiplication complete.\n");
    
    // Write the result to output file
    output_file = fopen("output.data", "w");
    if (output_file == NULL) {
        printf("Error: Could not create output.data\n");
        return 1;
    }

    output_file_raw = fopen("output_raw.data", "w");
    if (output_file_raw == NULL) {
        printf("Error: Could not create output_raw.data\n");
        return 1;
    }
    
    // Write the result matrix to file
    for (int i = 0; i < ROW_SIZE; i++) {
        for (int j = 0; j < COL_SIZE; j++) {
            fprintf(output_file, "%d.%06d\n", fxp_to_decimal_int_part(result[i * COL_SIZE + j]), 
                            fxp_to_decimal_frac_part(result[i * COL_SIZE + j]));
        }
    }

    for (int i = 0; i < ROW_SIZE; i++) {
        for (int j = 0; j < COL_SIZE; j++) {
            fprintf(output_file_raw, "%d\n", fxp_get_raw_value(result[i * COL_SIZE + j]) );
        }
    }
    
    fclose(output_file);
    fclose(output_file_raw);
    printf("Results written to output.data and output_raw.data\n");
    
    // Print first few elements for verification
    printf("\nFirst few elements of result matrix:\n");
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            printf("%d.%06d ", fxp_to_decimal_int_part(result[i * COL_SIZE + j]), 
                            fxp_to_decimal_frac_part(result[i * COL_SIZE + j]));
        }
        printf("\n");
    }
    
    // Compare with check.data
    check_file = fopen("check.data", "r");
    if (check_file == NULL) {
        printf("Error: Could not open check.data\n");
        return 1;
    }
    
    // Check if the number of non-empty lines matches
    int output_lines = ROW_SIZE * COL_SIZE;
    int check_lines = count_non_empty_lines(check_file);
    
    if (output_lines != check_lines) {
        printf("ERROR: Size mismatch! Output has %d elements, check.data has %d elements\n", 
               output_lines, check_lines);
        fclose(check_file);
        return 1;
    }
    
    // Calculate Mean Square Error
    double mse = 0.0;
    int idx = 0;
    while (fgets(line, MAX_LINE_LENGTH, check_file) != NULL) {
        // Skip empty lines and comments
        if (strlen(line) <= 1 || line[0] == '%') {
            continue;
        }
        
        double check_value = atof(line);
        double result_value = fxp_to_float(result[idx]);
        double diff = check_value - result_value;
        // printf("check_value: %f, result_value: %f, diff: %f\n", check_value, result_value, diff);
        mse += diff * diff;
        idx++;
    }
    
    mse /= output_lines;  // Calculate mean
    
    printf("\nMean Square Error: %.10f\n", mse);
    if (mse > 1e-6) {  // Threshold for considering results different
        printf("WARNING: Results differ significantly from check.data\n");
    } else {
        printf("Results match check.data within acceptable tolerance\n");
    }
    
    fclose(check_file);
    return 0;
} 