#ifndef GEMM_H
#define GEMM_H

#include <fxp/fxp.h>

// Matrix dimensions
#define ROW_SIZE 64
#define COL_SIZE 64
#define N (ROW_SIZE * COL_SIZE)

// Type definition for fixed-point numbers
typedef fxp_t TYPE;

// Function declaration
void gemm(TYPE m1[N], TYPE m2[N], TYPE prod[N]);

#endif // GEMM_H 