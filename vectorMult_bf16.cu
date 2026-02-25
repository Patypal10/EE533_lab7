
#include <stdio.h>
#include <cuda_bf16.h>

__global__ void mult_bfloat16(__nv_bfloat16* A, __nv_bfloat16* B, __nv_bfloat16* C, int16_t N) {
    int16_t i = threadIdx.x;
    if (i < N) {
        C[i] = __hmul(A[i], B[i]);
    }
}

int main() {
    const int N = 1 << 10;  // 1028 elements
    size_t size = N * sizeof(__nv_bfloat16);

    // Allocate host memory
    __nv_bfloat16* h_A = (__nv_bfloat16*)malloc(size);
    __nv_bfloat16* h_B = (__nv_bfloat16*)malloc(size);
    __nv_bfloat16* h_C = (__nv_bfloat16*)malloc(size);

    // Initialize host vectors
    for (int i = 0; i < N; i++) {
        h_A[i] = __float2bfloat16_rn(1.0f);
        h_B[i] = __float2bfloat16_rn(2.0f);
    }

    // Allocate device memory
    __nv_bfloat16 *d_A, *d_B, *d_C;
    cudaMalloc((void**)&d_A, size);
    cudaMalloc((void**)&d_B, size);
    cudaMalloc((void**)&d_C, size);

    // Copy data to device
    cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, size, cudaMemcpyHostToDevice);

    // Launch kernel
    //int threadsPerBlock = 256;
    //int blocksPerGrid = (N + threadsPerBlock - 1) / threadsPerBlock;
    mult_bfloat16<<<1, 8>>>(d_A, d_B, d_C, N);

    // Copy result back to host
    cudaMemcpy(h_C, d_C, size, cudaMemcpyDeviceToHost);

    // Free memory
    cudaFree(d_A);
    cudaFree(d_B);
    cudaFree(d_C);
    free(h_A);
    free(h_B);
    free(h_C);

    return 0;
}
