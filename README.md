# 🆘 Disaster Relief DAO

A decentralized autonomous organization built on Stacks blockchain that coordinates rapid funding to verified addresses during crisis situations.

## 🌟 Features

- 🏛️ **DAO Governance**: Stake-based membership with voting rights
- 🚨 **Crisis Declaration**: Members can declare emergencies requiring immediate attention
- 💰 **Relief Proposals**: Submit funding requests for verified disaster victims
- 🗳️ **Democratic Voting**: Transparent proposal voting with configurable quorum
- ✅ **Address Verification**: Ensures funds reach legitimate recipients
- 📞 **Emergency Contacts**: Maintain verified contact information for rapid response
- 💎 **Treasury Management**: Secure fund management with donation capabilities

## 🚀 Quick Start

### Join the DAO

```clarity
(contract-call? .disaster-relief join-dao u1000000)
```

### Declare a Crisis

```clarity
(contract-call? .disaster-relief declare-crisis 
  "Earthquake in Region X" 
  "Magnitude 7.2 earthquake requiring immediate relief"
  u5)
```

### Submit Relief Proposal

```clarity
(contract-call? .disaster-relief submit-relief-proposal
  u1
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  u500000
  "Emergency medical supplies for 100 families")
```

### Vote on Proposals

```clarity
(contract-call? .disaster-relief vote-on-proposal u1 true)
```

## 📊 Contract Functions

### 🏛️ DAO Management

| Function | Description |
|----------|-------------|
| `join-dao` | Join DAO by staking STX tokens |
| `leave-dao` | Leave DAO and withdraw stake |
| `donate-to-treasury` | Add funds to DAO treasury |

### 🚨 Crisis Management

| Function | Description |
|----------|-------------|
| `declare-crisis` | Declare new emergency situation |
| `deactivate-crisis` | Close resolved crisis |

### 💰 Relief Operations

| Function | Description |
|----------|-------------|
| `submit-relief-proposal` | Propose funding for verified recipient |
| `vote-on-proposal` | Cast vote on active proposal |
| `execute-proposal` | Execute approved proposal after voting period |

### ✅ Verification

| Function | Description |
|----------|-------------|
| `verify-address` | Verify recipient address (owner only) |
| `add-emergency-contact` | Add emergency contact information |
| `verify-emergency-contact` | Verify contact information (owner only) |

### ⚙️ Configuration

| Function | Description |
|----------|-------------|
| `update-voting-period` | Modify voting duration (owner only) |
| `update-min-quorum` | Set minimum quorum percentage (owner only) |

## 📖 Read-Only Functions

- `get-dao-info` - Get overall DAO statistics
- `get-member-info` - Check member status and stake
- `get-proposal` - Get proposal details
- `get-crisis` - Get crisis information
- `get-vote` - Check specific vote
- `get-emergency-contact` - Get contact information
- `is-proposal-executable` - Check if proposal can be executed

## 🔧 Configuration

### Default Settings

- **Voting Period**: 1440 blocks (~10 days)
- **Minimum Quorum**: 50% of members
- **Crisis Severity**: 1-5 scale (5 = most severe)

### Severity Levels

| Level | Description |
|-------|-------------|
| 1 | Minor incident |
| 2 | Local emergency |
| 3 | Regional disaster |
| 4 | National crisis |
| 5 | International emergency |

## 🛡️ Security Features

- ✅ Owner-only functions for critical operations
- ✅ Address verification requirement for recipients
- ✅ Stake-based membership prevents spam
- ✅ Time-locked voting periods
- ✅ Quorum requirements for proposal execution
- ✅ Treasury protection with balance checks

## 🏗️ Development

### Testing

```bash
clarinet test
```

### Check Contract

```bash
clarinet check
```

### Deploy

```bash
clarinet integrate
```

## 📄 License

MIT License - Built for humanitarian purposes

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Submit pull request with clear description

---

*Built with ❤️ for disaster relief coordination*
