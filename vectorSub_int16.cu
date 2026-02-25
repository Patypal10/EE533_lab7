

#include <stdio.h>

__global__ void vectorSub_int16(const int16_t* A, const int16_t* B, int16_t* C, int16_t N) {
    int16_t i = threadIdx.x;
    if (i < N) {
        C[i] = A[i] - B[i];
    }
}

int main() {
    const int16_t N = 1 << 10;  // 1028 elements
    size_t size = N * sizeof(int16_t);

    // Allocate host memory
    int16_t* h_A = (int16_t*)malloc(size);
    int16_t* h_B = (int16_t*)malloc(size);
    int16_t* h_C = (int16_t*)malloc(size);

    // Initialize host vectors
    for (int i = 0; i < N; i++) {
        h_A[i] = (int16_t)1;
        h_B[i] = (int16_t)2;
    }

    // Allocate device memory
    int16_t *d_A, *d_B, *d_C;
    cudaMalloc((void**)&d_A, size);
    cudaMalloc((void**)&d_B, size);
    cudaMalloc((void**)&d_C, size);

    // Copy data to device
    cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, size, cudaMemcpyHostToDevice);

    // Launch kernel
    //int threadsPerBlock = 256;
    //int blocksPerGrid = (N + threadsPerBlock - 1) / threadsPerBlock;
    vectorSub_int16<<<1, 8>>>(d_A, d_B, d_C, N);

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
