# kn - kubectl with namespace memory

Lightweight kubectl wrapper that remembers your last namespace and formats logs beautifully.

## ✨ Features

- 🧠 **Remember namespace** - Automatically use last namespace
- 📝 **Format logs** - Clean, readable log output
- ⚡ **Works with watch** - `watch -n1 kn top pod` just works
- 🔄 **Tab completion** - Full kubectl completion support
- 🪶 **Lightweight** - Just a bash function, no dependencies

## 🚀 Quick Install
```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/kn/main/install.sh | bash
source ~/.bashrc
```

## 📖 Usage
```bash
kn get pods                    # use default or last namespace
kn -n production get svc       # switch to production
kn get deploy                  # still in production
kn logs my-pod                 # formatted logs
watch -n1 kn top pod my-pod    # works with watch!
```

## 🗑️ Uninstall

Remove these lines from `~/.bashrc`:
```bash
sed -i '/# kyai - kubectl with namespace memory/,/# End of kyai installation/d' ~/.bashrc
```
```
