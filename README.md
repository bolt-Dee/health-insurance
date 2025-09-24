# Health Goal Insurance Smart Contract

A Clarity smart contract implementing a stake-to-stay-healthy insurance system where participants can earn rewards for meeting health goals.

## 🎯 Overview

This smart contract enables the creation and management of health goal programs where participants can:
- Stake STX tokens against their health commitments
- Get verified for completing health goals
- Earn rewards for successful completion
- Participate in a communal pool system

## 🏗 Features

### Program Management
- Create health programs with configurable parameters
- Set program duration and reward amounts
- Manage reward pools with STX tokens
- Program lifecycle management (create/close)

### Participant System
```
Stake → Verify → Claim → Reward
```

### Administrative Features
- Program creation and closure
- Reward pool management
- Verification system
- Communal pool administration

## 📋 Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for deployment
- Node.js (for testing environment)

## 🚀 Quick Start

```bash
# Clone the repository
git clone <repository-url>

# Navigate to project directory
cd health-insurance

# Run Clarinet console
clarinet console

# Deploy contract (in Clarinet console)
(contract-call? .health-insurance create-program u1)
```

## 💻 Usage

### Create a Program
```clarity
(contract-call? .health-insurance create-program u1)
```

### Join a Program
```clarity
(contract-call? .health-insurance join-program u1)
```

### Submit Proof
```clarity
(contract-call? .health-insurance submit-proof u1 tx-sender true)
```

## 🔐 Security

- Authorization checks for all operations
- Transfer amount validation
- Block height validation
- Event logging with nonce

## ⚠️ Warning

This is example code and requires a security audit before production use.

## 📄 License

MIT License

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📞 Support

Open an issue in the repository for:
- Bug reports
- Feature requests
- General questions

## 🗺 Roadmap

- [ ] Enhanced verification system
- [ ] Multiple verifier support
- [ ] Automated reward distribution
- [ ] Advanced event tracking
- [ ] UI integration

## 🏆 Acknowledgments

- Stacks Foundation
- Clarity Lang Documentation
- Community Contributors
