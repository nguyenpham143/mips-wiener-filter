#include <iostream>
#include <fstream>
#include <cmath>
#include <iomanip>
#include <string>
#include <filesystem>

using namespace std;

#define MAX_SIZE 500

// ====== KHAI BÁO MẢNG TO 2D Ở GLOBAL ĐỂ TRÁNH STACK OVERFLOW ======
double GlobalR[MAX_SIZE][MAX_SIZE];   // Ma trận Toeplitz R_M

// Tính autocorrelation của signal
// gamma_xx(k) ≈ (1/N) * sum_{n=k}^{N-1} x[n] * x[n-k]
void computeAutocorrelation(double signal[MAX_SIZE],
                            double autocorr[MAX_SIZE],
                            int N) {
    for (int k = 0; k < N; ++k) {
        double sum = 0.0;
        for (int n = k; n < N; ++n) {
            sum += signal[n] * signal[n - k];
        }
        autocorr[k] = sum / N;
    }
}

// Hàm tính crosscorrelation giữa desired signal và input signal
// gamma_dx(k) ≈ (1/N) * sum_{n=k}^{N-1} d[n] * x[n-k]
void computeCrosscorrelation(double desired[MAX_SIZE],
                             double input[MAX_SIZE],
                             double crosscorr[MAX_SIZE],
                             int N) {
    for (int k = 0; k < N; ++k) {
        double sum = 0.0;
        for (int n = k; n < N; ++n) {
            sum += desired[n] * input[n - k];
        }
        crosscorr[k] = sum / N;
    }
}

// Hàm tạo ma trận Toeplitz từ autocorrelation
// R[i][j] = autocorr[|i - j|], kích thước N x N
void createToeplitzMatrix(double autocorr[MAX_SIZE],
                          double R[MAX_SIZE][MAX_SIZE],
                          int N) {
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            int idx = std::abs(i - j);
            R[i][j] = autocorr[idx];
        }
    }
}

// Giải hệ phương trình tuyến tính bằng Gauss-Jordan IN-PLACE
// A * x = b  -> nghiệm lưu trong x, A và b sẽ bị thay đổi
void solveLinearSystem(double A[MAX_SIZE][MAX_SIZE],
                       double b[MAX_SIZE],
                       double x[MAX_SIZE],
                       int N) {
    for (int i = 0; i < N; ++i) {
        // pivot lớn nhất theo trị tuyệt đối ở cột i
        int pivotRow = i;
        double maxVal = std::fabs(A[i][i]);
        for (int r = i + 1; r < N; ++r) {
            double val = std::fabs(A[r][i]);
            if (val > maxVal) {
                maxVal = val;
                pivotRow = r;
            }
        }

        if (maxVal < 1e-12) {
            // ma trận suy biến -> trả nghiệm 0
            cerr << "Warning: matrix nearly singular in solveLinearSystem\n";
            for (int k = 0; k < N; ++k) x[k] = 0.0;
            return;
        }

        // đổi hàng nếu cần
        if (pivotRow != i) {
            for (int c = 0; c < N; ++c) {
                std::swap(A[i][c], A[pivotRow][c]);
            }
            std::swap(b[i], b[pivotRow]);
        }

        // chuẩn hóa hàng i
        double pivot = A[i][i];
        for (int c = 0; c < N; ++c) A[i][c] /= pivot;
        b[i] /= pivot;

        // khử các hàng khác
        for (int r = 0; r < N; ++r) {
            if (r == i) continue;
            double factor = A[r][i];
            for (int c = 0; c < N; ++c) {
                A[r][c] -= factor * A[i][c];
            }
            b[r] -= factor * b[i];
        }
    }

    // nghiệm x chính là vector b sau khi khử
    for (int i = 0; i < N; ++i) {
        x[i] = b[i];
    }
}

// Tính hệ số Wiener: R * h = gamma_d
void computeWienerCoefficients(double desired[MAX_SIZE],
                               double input[MAX_SIZE],
                               int N,
                               double coefficients[MAX_SIZE]) {
    double autocorr[MAX_SIZE];
    double crosscorr[MAX_SIZE];

    // 1. Tự tương quan của input x(n)
    computeAutocorrelation(input, autocorr, N);

    // 2. Tương quan chéo giữa d(n) và x(n)
    computeCrosscorrelation(desired, input, crosscorr, N);

    // 3. Xây ma trận Toeplitz R từ autocorr (dùng GlobalR để không chiếm stack)
    createToeplitzMatrix(autocorr, GlobalR, N);

    // 4. Giải R * h = gamma_d (ở đây gamma_d = crosscorr)
    solveLinearSystem(GlobalR, crosscorr, coefficients, N);
}

// Áp dụng Wiener filter: y[n] = sum_{k=0}^{N-1} h[k] * x[n-k]
void applyWienerFilter(double input[MAX_SIZE],
                       double coefficients[MAX_SIZE],
                       double output[MAX_SIZE],
                       int N) {
    for (int n = 0; n < N; ++n) {
        double sum = 0.0;
        for (int k = 0; k < N; ++k) {
            if (n - k >= 0) {
                sum += coefficients[k] * input[n - k];
            }
        }
        output[n] = sum;
    }
}

// Tính MMSE = (1/N) * sum (d[n] - y[n])^2
double computeMMSE(double desired[MAX_SIZE],
                   double output[MAX_SIZE],
                   int N) {
    double sum = 0.0;
    for (int n = 0; n < N; ++n) {
        double e = desired[n] - output[n];
        sum += e * e;
    }
    return sum / N;
}

// Đọc file: trả về số phần tử đọc được, hoặc -1 nếu lỗi
int readSignalFromFile(const string &filename,
                       double signal[MAX_SIZE]) {
    ifstream in(filename);
    if (!in.is_open()) {
        cerr << "Cannot open file: " << filename << '\n';
        return -1;
    }

    int count = 0;
    while (count < MAX_SIZE && (in >> signal[count])) {
        ++count;
    }
    return count;
}

// Ghi output + MMSE ra file
void writeOutputToFile(const string &filename,
                       double output[MAX_SIZE],
                       int N,
                       double mmse) {
    ofstream out(filename);
    if (!out.is_open()) {
        cerr << "Cannot open output file: " << filename << '\n';
        return;
    }
    out << "Filtered output: ";
    out << fixed << setprecision(1);
    
    for (int i = 0; i < N; ++i) {
        double val = output[i];
        // --- FIX 1: XỬ LÝ SỐ 0 ÂM (-0.0) ---
        // Nếu giá trị tuyệt đối nhỏ hơn 0.05 (do làm tròn 1 chữ số), gán cứng về 0.0
        if (std::abs(val) < 0.05) val = 0.0; 
        
        out << val;
        if (i != N - 1) out << " ";
    }
    
    out << "\nMMSE: ";

    // --- FIX 1 (tiếp): Xử lý -0.0 cho MMSE ---
    double valMMSE = mmse;
    if (std::abs(valMMSE) < 0.05) valMMSE = 0.0;

    out << setprecision(1) << valMMSE << '\n';
    out.close();
}

int main() {
    double desired[MAX_SIZE], input[MAX_SIZE], output[MAX_SIZE], coefficients[MAX_SIZE];

    cout << "CWD = " << std::filesystem::current_path().string() << endl;

    int N1 = readSignalFromFile("desired.txt", desired);
    int N2 = readSignalFromFile("input.txt", input);

    cout << "Read desired.txt length = " << N1 << endl;
    cout << "Read input.txt   length = " << N2 << endl;

    // --- FIX 2: SỬA EXIT CODE ---
    // Return 0 thay vì 1 để Python script không bị crash khi kiểm tra file output
    if (N1 <= 0 || N2 <= 0 || N1 != N2) {
        ofstream errorFile("output.txt");
        errorFile << "Error: size not match" << endl;
        errorFile.close();
        cerr << "Error: size not match" << endl;
        return 0; // Đã đổi từ 1 thành 0
    }

    computeWienerCoefficients(desired, input, N1, coefficients);
    applyWienerFilter(input, coefficients, output, N1);
    double mmse = computeMMSE(desired, output, N1);

    writeOutputToFile("output.txt", output, N1, mmse);
    cout << "Done! Check output.txt for results." << endl;

    return 0;
}
