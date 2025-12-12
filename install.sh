#!/bin/bash

# kyai - kubectl with namespace memory & log formatting
# Installation script

set -e

BASHRC="$HOME/.bashrc"
ZSH_RC="$HOME/.zshrc"

echo "🚀 Installing kyai - kubectl with namespace memory..."

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Install bash-completion if not present
if ! dpkg -l | grep -q bash-completion 2>/dev/null; then
    echo "📦 Installing bash-completion..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y bash-completion
    elif command -v yum &> /dev/null; then
        sudo yum install -y bash-completion
    fi
fi

if grep -q "# kyai - kubectl with namespace memory" "$BASHRC" 2>/dev/null; then
    echo "⚠️  kyai is already installed in $BASHRC"
    read -p "Do you want to reinstall? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    sed -i.bak '/# kyai - kubectl with namespace memory/,/# End of kyai installation/d' "$BASHRC"
fi

cat >> "$BASHRC" << 'EOF'
# kyai - kubectl with namespace memory

# Enable bash completion
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

# Enable kubectl completion
if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash)
fi

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
        command kubectl $namespace_arg "$@" | awk '
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
        }'
    else
        command kubectl $namespace_arg "$@"
    fi
}

# Setup completion for k command
_k_completion() {
    local cur prev words cword
    _init_completion -n : || return
    
    # Replace 'k' with 'kubectl' for completion
    local cmd=kubectl
    COMP_WORDS[0]=$cmd
    COMP_LINE=${COMP_LINE/k /kubectl }
    
    # Use kubectl's completion function
    if declare -F _kubectl > /dev/null; then
        _kubectl
    elif declare -F __start_kubectl > /dev/null; then
        __start_kubectl
    fi
}

complete -F _k_completion k

kw() {
    if [[ "$1" == "top" && "$2" == "pod" ]]; then
        local pod_name="$3"
        local history_file="/tmp/kw_history_${pod_name}.txt"

        if [[ -f "$history_file" ]]; then
            local file_age=$(($(date +%s) - $(stat -c %Y "$history_file" 2>/dev/null || stat -f %m "$history_file" 2>/dev/null)))
            if [[ $file_age -gt 3600 ]]; then
                rm "$history_file"
            fi
        fi

        watch -n1 "bash -c '
            OUTPUT=\$(kubectl -n $LAST_K8S_NAMESPACE top pod $pod_name 2>&1)

            if echo \"\$OUTPUT\" | grep -q \"NAME\"; then
                CPU=\$(echo \"\$OUTPUT\" | tail -1 | awk \"{print \\\$2}\" | sed \"s/m//\")
                MEM=\$(echo \"\$OUTPUT\" | tail -1 | awk \"{print \\\$3}\" | sed \"s/Mi//\")

                echo \"\$CPU \$MEM\" >> $history_file
                tail -5 $history_file > ${history_file}.tmp && mv ${history_file}.tmp $history_file

                mapfile -t HISTORY < $history_file

                echo \"Pod: $pod_name | Namespace: $LAST_K8S_NAMESPACE\"
                echo \"===========================================\"
                echo \"\$OUTPUT\"
                echo \"\"
                echo \"CPU History (last 5 samples):\"

                MAX_CPU=1000
                for line in \"\${HISTORY[@]}\"; do
                    c=\$(echo \$line | awk \"{print \\\$1}\")
                    if [[ \$c -gt \$MAX_CPU ]]; then
                        MAX_CPU=\$c
                    fi
                done

                for line in \"\${HISTORY[@]}\"; do
                    c=\$(echo \$line | awk \"{print \\\$1}\")
                    bars=\$((c * 50 / MAX_CPU))
                    printf \"%4sm |\" \$c
                    printf \"█%.0s\" \$(seq 1 \$bars)
                    echo \"\"
                done

                echo \"\"
                echo \"Memory History (last 5 samples):\"

                MAX_MEM=3000
                for line in \"\${HISTORY[@]}\"; do
                    m=\$(echo \$line | awk \"{print \\\$2}\")
                    if [[ \$m -gt \$MAX_MEM ]]; then
                        MAX_MEM=\$m
                    fi
                done

                for line in \"\${HISTORY[@]}\"; do
                    m=\$(echo \$line | awk \"{print \\\$2}\")
                    bars=\$((m * 50 / MAX_MEM))
                    printf \"%4sMi |\" \$m
                    printf \"█%.0s\" \$(seq 1 \$bars)
                    echo \"\"
                done
            else
                echo \"\$OUTPUT\"
            fi
        '"
    else
        watch -n1 "kubectl -n $LAST_K8S_NAMESPACE $*"
    fi
}

export LAST_K8S_NAMESPACE

# End of kyai installation
EOF

echo "✅ kyai installed successfully!"
echo ""
echo "📝 To start using kyai, run:"
echo "   source ~/.bashrc"
echo "   # or restart your terminal"
echo ""
echo "🎯 Usage examples:"
echo "   k get pods                      # use remembered namespace"
echo "   k get po<TAB>                   # tab completion works!"
echo "   k -n production get svc         # switch to production"
echo "   k logs my-pod                   # formatted logs"
echo "   kw top pod my-pod               # watch with graphs!"
echo ""
echo "⭐ Star us on GitHub: https://github.com/ITPATJIDR/Kyai"
