# Kyai - kubectl with namespace memory

Lightweight kubectl wrapper that remembers your last namespace and formats logs beautifully.

## ✨ Features

- 🧠 **Remember namespace** - Automatically use last namespace
- 📝 **Format logs** - Clean, readable log output
- 🔄 **Tab completion** - Full kubectl completion support
- 🪶 **Lightweight** - Just a bash function, no dependencies
- 📍 **Active context visibility** - Always show current namespace prominently

## 🚀 Quick Install
```bash
curl -fsSL https://raw.githubusercontent.com/ITPATJIDR/Kyai/refs/heads/main/install.sh | bash
source ~/.bashrc
```

## 📖 Usage
```bash
k get pods                    # use default or last namespace
k -n production get svc       # switch to production
k get deploy                  # still in production
k logs my-pod                 # formatted logs
kw top pod my-pod             # works with watch!
```

## 🗑️ Uninstall

Remove these lines from `~/.bashrc`:
```bash
sed -i '/# kyai - kubectl with namespace memory/,/# End of kyai installation/d' ~/.bashrc
```
