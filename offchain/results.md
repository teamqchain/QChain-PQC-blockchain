## 📊 Performance Benchmarks

The following benchmarks compare the speed across all three ML-DSA security levels for both implementations.

### 1. `go-bindings` (liboqs-go)
*Optimized C-bindings. Requires Docker.*

| Operation | Security Level | Speed (ms/op) |
| :--- | :--- | :--- |
| **Key Generation** | ML-DSA-44 | 0.041 |
| | ML-DSA-65 | 0.071 | 
| | ML-DSA-87 | 0.122 | 
| **Signing** | ML-DSA-44 | 0.091 |
| | ML-DSA-65 | 0.147 | 
| | ML-DSA-87 | 0.212 | 
| **Verification** | ML-DSA-44 | 0.037 |
| | ML-DSA-65 | 0.064 | 
| | ML-DSA-87 | 0.113 |
| **Total Workflow** | ML-DSA-44 | 0.167 |
| | ML-DSA-65 | 0.280 | 
| | ML-DSA-87 | 0.438 |

### 2. `go-native` (Cloudflare CIRCL)
*Pure Go. Runs natively anywhere.*

| Operation | Security Level | Speed (ms/op) |
| :--- | :--- | :--- |
| **Key Generation** | ML-DSA-44 | 0.085 |
| | ML-DSA-65 | 0.153 |
| | ML-DSA-87 | 0.228 |
| **Signing** | ML-DSA-44 | 0.196 |
| | ML-DSA-65 | 0.373 |
| | ML-DSA-87 | 0.520 |
| **Verification** | ML-DSA-44 | 0.034 |
| | ML-DSA-65 | 0.046 |
| | ML-DSA-87 | 0.065 |
| **Total Workflow** | ML-DSA-44 | 0.321 |
| | ML-DSA-65 | 0.513 | 
| | ML-DSA-87 | 0.621 |

*In our benchmarks, CIRCL’s ML-DSA implementation exhibits slower key generation and signing compared to liboqs-go, while outperforming it in verification performance.*

![Graph](../../assets/graph_MLDSA_implementations.jpg)
