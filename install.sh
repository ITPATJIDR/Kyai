#!/bin/bash

# kyai - kubectl with namespace memory & log formatting
# Installation script

set -e

BASHRC="$HOME/.bashrc"
ZSH_RC="$HOME/.zshrc"

KYAI_CODE='
# kyai - kubectl with namespace memory
export LAST_K8S_NAMESPACE="default"

k() {
    local namespace_arg=""
    local namespace_value=""
    local found_namespace=false
    local is_logs_command=false
    
    if [[ "$1" == "logs" ]]; then
        is_logs_command=true
    fi
    
    for arg in "$@"; do
        if [[ "$found_namespace" == true ]]; then
            namespace_value="$arg"
            export LAST_K8S_NAMESPACE="$namespace_value"
            found_namespace=false
        elif [[ "$arg" == "-n" || "$arg" == "--namespace" ]]; then
            found_namespace=true
        fi
    done
    
    if [[ "$namespace_value" == "" ]]; then
        namespace_arg="-n $LAST_K8S_NAMESPACE"
    fi
    
    if [[ "$is_logs_command" == true ]]; then
        command kubectl $namespace_arg "$@" | awk '\''
        BEGIN { prev = "" }
        {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            if (length($0) == 0) next
            if ($0 == prev) next
            if (match($0, /^[0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
                print ""
                print $0
            } else if (match($0, /(ERROR|WARN|INFO|DEBUG|FATAL)/)) {
                print ""
                print $0
            } else {
                print ""
                print $0
            }
            prev = $0
        }'\''
    else
        command kubectl $namespace_arg "$@"
    fi
}

export -f k
export LAST_K8S_NAMESPACE


_k_completion() {
    local cur prev words cword
    _init_completion || return
    local cmd=kubectl
    COMP_WORDS[0]=$cmd
    __start_kubectl
}

complete -F _k_completion k
# End of kyai installation
'

echo "🚀 Installing kyai - kubectl with namespace memory..."

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if grep -q "# kyai - kubectl with namespace memory" "$BASHRC" 2>/dev/null; then
    echo "⚠️  kyai is already installed in $BASHRC"
    read -p "Do you want to reinstall? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    sed -i '/# kyai - kubectl with namespace memory/,/# End of kyai installation/d' "$BASHRC"
fi

echo "$KYAI_CODE" >> "$BASHRC"

echo "✅ kyai installed successfully!"
echo ""
echo "📝 To start using kyai, run:"
echo "   source ~/.bashrc"
echo ""
echo "🎯 Usage examples:"
echo "   k get pods                    # use remembered namespace"
echo "   k -n production get svc       # switch to production"
echo "   k logs my-pod                 # formatted logs"
echo "   watch -n1 k top pod my-pod    # works with watch!"
echo ""
echo "⭐ Star us on GitHub: https://github.com/yourusername/kyai"
