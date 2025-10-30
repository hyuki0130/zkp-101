# Coinbase Attestor Advanced ZKP Frontend

Advanced Zero-Knowledge Proof frontend for Coinbase KYC attestation verification with on-chain proof verification.

## Features

- 🔐 Complete privacy-enhanced ZKP circuit
- ✅ User ownership verification via ECDSA signature
- ✅ Coinbase signer verification via Merkle proof
- ✅ EIP-1559 transaction parsing and validation
- 🌐 On-chain proof verification (Base mainnet)
- 🚀 Browser-based proof generation with bb.js UltraHonk

## Quick Start

### Development Mode

```bash
npm install
npm run dev
```

Access at: http://localhost:5174

### Docker Deployment (Recommended for Demo)

**Option 1: HTTP (Development)**

```bash
./docker-up.sh
```

This will serve on http://localhost:8080

**Option 2: HTTPS (Production - Faster ZKP)**

```bash
./docker-up-https.sh
```

This will:
1. Generate self-signed SSL certificate (if not exists)
2. Build the Docker image with HTTPS support
3. Serve on https://localhost

**Why HTTPS?**
- Enables `SharedArrayBuffer` for multithreading
- **2x faster proof generation** (17s vs 36s)
- Required for production deployments

**To stop:**

```bash
./docker-down.sh  # For HTTP
# or
docker-compose -f docker-compose-https.yml down  # For HTTPS
```

### Alternative Scripts

```bash
# Original scripts (also work)
./start-docker.sh  # Build and start
./stop-docker.sh   # Stop and remove

# Direct docker-compose commands
docker-compose up -d --build  # Build and start
docker-compose down           # Stop and remove
docker-compose logs -f        # View logs
docker-compose ps             # Check status
```

## How It Works

### Step 1: Connect Wallet
Connect your MetaMask wallet to the application.

### Step 2: Generate Inputs
Enter your Base transaction hash containing the Coinbase attestation. The app will:
- Fetch the attestation from Base EAS
- Extract transaction data
- Recover signer public keys
- Build Merkle proof

### Step 3: Generate Proof
Generate a Zero-Knowledge Proof that verifies:
- You own the address (via signature on signal_hash)
- Transaction was signed by authorized Coinbase signer (via Merkle proof)
- Transaction attests to your address

**All without revealing your address or transaction details!**

### Step 4: Verify Proof (Local)
Verify the proof locally using bb.js in the browser.

### Step 5: Verify Proof (On-Chain)
Submit the proof to the deployed verifier contract on Base mainnet for trustless verification.

## Architecture

```
Browser
  ├── Input Generation (main.js)
  │   ├── EAS Attestation Fetch
  │   ├── Transaction Parsing
  │   ├── Public Key Recovery
  │   └── Merkle Tree Construction
  │
  ├── Proof Generation (bb.js UltraHonk)
  │   ├── Circuit: advanced.json
  │   ├── Backend: UltraHonk with Keccak ZK
  │   └── SRS: Downloaded from crs.aztec.network
  │
  ├── Local Verification (bb.js)
  │   └── Verify proof in browser
  │
  └── On-Chain Verification (ethers.js)
      └── Contract: 0x4b0C010346093fd09e1cBbeA6D7Af1888eDF55C8
```

## Circuit Information

- **Circuit**: Advanced Coinbase Attestor
- **Backend**: UltraHonk (bb.js v0.87.0)
- **Public Inputs**: signal_hash (32 bytes), signer_list_merkle_root (32 bytes)
- **Private Inputs**: user_address, signatures, pubkeys, raw_transaction, merkle_proof
- **Verifier Contract**: 0x4b0C010346093fd09e1cBbeA6D7Af1888eDF55C8 (Base mainnet)

## Configuration

### CSP Headers
The application requires specific CSP headers for WASM and SharedArrayBuffer:
- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`
- `Content-Security-Policy`: Allows connections to Base RPC, EAS, and Aztec CRS

### Allowed Origins
- `https://mainnet.base.org` - Base RPC
- `https://base.easscan.org` - EAS GraphQL
- `https://crs.aztec.network` - Aztec SRS download

## Docker Details

### Image Size
- Base image: nginx:alpine (~7MB)
- Built app: ~10-15MB
- Total image: ~20-25MB

### Security Features
- Non-root user
- Read-only filesystem (except /tmp, /var/cache/nginx, /var/run)
- Security headers (CSP, X-Frame-Options, etc.)
- Health check endpoint
- Minimal attack surface

### Ports
- Internal: 80
- External: 8080 (configurable in docker-compose.yml)

## Troubleshooting

### Docker Issues
- **Docker not running**: Start Docker daemon first
- **Port in use**: Change port in start-docker.sh or docker-compose.yml
- **Build fails**: Ensure you're in the frontend directory

### Application Issues
- **Proof generation fails**: Check browser console for errors
- **On-chain verification fails**: Ensure wallet is connected and on Base mainnet
- **CSP errors**: Check nginx.conf for proper CSP configuration

## Development

### Project Structure
```
frontend/
├── index.html          # Main HTML file
├── main.js             # Application logic
├── vite.config.js      # Vite configuration
├── package.json        # Dependencies
├── Dockerfile          # Docker build config
├── nginx.conf          # Nginx server config
├── docker-compose.yml  # Docker Compose config
├── start-docker.sh     # Quick start script
└── stop-docker.sh      # Stop script
```

### Build Production
```bash
npm run build
```

Output in `dist/` directory.

## License

MIT

## Links

- Circuit: `../src/main.nr`
- Verifier Contract: https://basescan.org/address/0x4b0C010346093fd09e1cBbeA6D7Af1888eDF55C8
- Documentation: See README.docker.md for detailed Docker guide
