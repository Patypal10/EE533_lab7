
#include <stdio.h>
#include <cuda_bf16.h>

__global__ void vectorRelu_bfloat16(__nv_bfloat16* A, __nv_bfloat16* B, int16_t N) {
    int i = threadIdx.x;
    if (i < N) {
         B[i] = __hmax(0.0f, A[i]);
    }
}

int main() {
    const int N = 1 << 10;  // 1028 elements
    size_t size = N * sizeof(__nv_bfloat16);

    // Allocate host memory
    __nv_bfloat16* h_A = (__nv_bfloat16*)malloc(size);
    __nv_bfloat16* h_B = (__nv_bfloat16*)malloc(size);

    // Initialize host vectors
    for (int i = 0; i < N; i++) {
        h_A[i] = __float2bfloat16_rn(1.0f);
    }

    // Allocate device memory
    __nv_bfloat16 *d_A, *d_B;
    cudaMalloc((void**)&d_A, size);
    cudaMalloc((void**)&d_B, size);

    // Copy data to device
    cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice);

    // Launch kernel
    //int threadsPerBlock = 256;
    //int blocksPerGrid = (N + threadsPerBlock - 1) / threadsPerBlock;
    vectorRelu_bfloat16<<<1, 8>>>(d_A, d_B, N);

    // Copy result back to host
    cudaMemcpy(h_B, d_B, size, cudaMemcpyDeviceToHost);

    // Free memory
    cudaFree(d_A);
    cudaFree(d_B);
    free(h_A);
    free(h_B);

    return 0;
}
