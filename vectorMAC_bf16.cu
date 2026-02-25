
#include <stdio.h>
#include <cuda_bf16.h>

__global__ void mac_bfloat16(__nv_bfloat16* A, __nv_bfloat16* B, __nv_bfloat16* C, __nv_bfloat16* D, int16_t N) {
    int16_t i = threadIdx.x;
    if (i < N) {
        D[i] = __hfma(A[i], B[i], C[i]);
    }
}

int main() {
    const int N = 1 << 10;  // 1028 elements
    size_t size = N * sizeof(__nv_bfloat16);

    // Allocate host memory
    __nv_bfloat16* h_A = (__nv_bfloat16*)malloc(size);
    __nv_bfloat16* h_B = (__nv_bfloat16*)malloc(size);
    __nv_bfloat16* h_C = (__nv_bfloat16*)malloc(size);
    __nv_bfloat16* h_D = (__nv_bfloat16*)malloc(size);

    // Initialize host vectors
    for (int i = 0; i < N; i++) {
        h_A[i] = __float2bfloat16_rn(1.0f);
        h_B[i] = __float2bfloat16_rn(2.0f);
        h_C[i] = __float2bfloat16_rn(3.0f);
    }

    // Allocate device memory
    __nv_bfloat16 *d_A, *d_B, *d_C, *d_D;
    cudaMalloc((void**)&d_A, size);
    cudaMalloc((void**)&d_B, size);
    cudaMalloc((void**)&d_C, size);
    cudaMalloc((void**)&d_D, size);

    // Copy data to device
    cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_C, h_C, size, cudaMemcpyHostToDevice);

    // Launch kernel
    //int threadsPerBlock = 256;
    //int blocksPerGrid = (N + threadsPerBlock - 1) / threadsPerBlock;
    mac_bfloat16<<<1, 8>>>(d_A, d_B, d_C, d_D, N);

    // Copy result back to host
    cudaMemcpy(h_D, d_D, size, cudaMemcpyDeviceToHost);

    // Free memory
    cudaFree(d_A);
    cudaFree(d_B);
    cudaFree(d_C);
    cudaFree(d_D);
    free(h_A);
    free(h_B);
    free(h_C);
    free(h_D);

    return 0;
}
