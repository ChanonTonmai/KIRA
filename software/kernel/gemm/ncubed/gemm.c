#include "gemm.h"
#include <fxp/fxp_util.h>

void gemm(TYPE m1[N], TYPE m2[N], TYPE prod[N]) {
    int i, j, k;
    int k_col, i_col;
    TYPE mult;

    outer:for(i = 0; i < ROW_SIZE; i++) {
        middle:for(j = 0; j < COL_SIZE; j++) {
            i_col = i * COL_SIZE;
            TYPE sum = fxp_from_real(0.0, 16, 16, true);  // Initialize sum to 0
            inner:for(k = 0; k < ROW_SIZE; k++) {
                k_col = k * COL_SIZE;
                // Perform fixed-point multiplication
                mult = fxp_mul(m1[i_col + k], m2[k_col + j]);



                // Perform fixed-point addition
                sum = fxp_add(sum, mult);

                if (i == 0 && j == 0) {
                    printf("m1[%d] = %d, m2[%d] = %d, mult = %d, sum = %d\n", i_col + k, m1[i_col + k], k_col + j, m2[k_col + j], mult.value, sum.value);
                    // print_fxp_decimal("mult", mult);
                }
            }
            prod[i_col + j] = sum;
        }
    }
} 