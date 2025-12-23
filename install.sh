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

    echo -e "\033[0;97;42m  CONTEXT: Namespace -> [ $LAST_K8S_NAMESPACE ]  \033[0m"
    
    if [[ "$is_logs_command" == true ]]; then
command kubectl $namespace_arg "$@" | awk '
        BEGIN {
            prev = ""
            # ANSI Color Codes
            RED="\033[0;31m"
            YELLOW="\033[0;33m"
            CYAN="\033[0;36m"
            GREEN="\033[0;32m"
            BLUE="\033[0;34m"
            NC="\033[0m" # No Color
        }

        {
            # 1. Clean up & Deduplication
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            if (length($0) == 0) next
            if ($0 == prev) next

            # 3. Handle Istio/Standard Structured Logs (2025-12-15T10:54:...)
            if ($0 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{6}Z/) {

                print ""

                timestamp = $1
                level = $2
                caller = $3

                message = ""
                for (i = 4; i <= NF; i++) {
                    message = message $i " "
                }
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", message)


                # ใช้ concatenation แทน printf ที่ซับซ้อน
                prefix = BLUE "[" level "]" NC " " CYAN timestamp NC " | " BLUE caller NC " | "

                if (level == "error") {
                    print prefix RED message NC
                } else if (level == "warn") {
                    print prefix YELLOW message NC
                } else {
                    # INFO / DEBUG: เน้น Latency/TTL ด้วยสีเขียว
                    formatted_message = message

                    gsub(/latency=([0-9.]+ms)/, GREEN "\\1" NC, formatted_message)
                    gsub(/ttl=([0-9hms.]+)/, GREEN "\\1" NC, formatted_message)

                    print prefix formatted_message
                }

            # 4. Handle Kubernetes Component Logs (I/W/E 1215 04:56:...)
            } else if ($0 ~ /^[IWE][0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{6}/) {

                print ""

                level = substr($0, 1, 1)
                timestamp = substr($0, 2, 18)

                # ตัดส่วนไฟล์ต้นทาง: 1 controller.go:95]
                match($0, /[0-9]+ [a-zA-Z0-9_/.-]+:[0-9]+\]/)
                if (RSTART > 0) {
                    message = substr($0, RSTART + RLENGTH)
                } else {
                    message = substr($0, 20)
                }

                gsub(/^[[:space:]]+/, "", message)

                # ใช้ concatenation แทน printf ที่ซับซ้อน
                prefix = BLUE "[" level "]" NC " " CYAN timestamp NC " | " BLUE "K8S_COMP" NC " | "

                if (level == "E") {
                    print prefix RED message NC
                } else if (level == "W") {
                    print prefix YELLOW message NC
                } else {
                    print prefix message
                }

            # 5. Handle JSON logs (pod_2)
            } else if ($0 ~ /^{.*}$/) {
                print ""

                line = $0
                if (line ~ /"level":"error"/) {
                    print RED line NC
                } else if (line ~ /"level":"warn"/) {
                    print YELLOW line NC
                } else {
                    print line
                }

            # 6. Handle Standard/Go/Nginx logs (pod_1, pod_3)
            } else if ($0 ~ /^[0-9]{4}[/-][0-9]{2}[/-][0-9]{2}/ || $0 ~ /\[(notice|info|warn|error|crit|emerg)\]/) {
                print ""

                line = $0

                if (line ~ /(ERROR|FATAL)/) {
                    print RED line NC
                } else if (line ~ /(WARN|notice)/) {
                    print YELLOW line NC
                } else {
                    print line
                }

            # 7. Handle SQL Query and HTTP Request (pod_1)
            } else if ($0 ~ /^(SELECT|INSERT|UPDATE|DELETE)/ || $0 ~ /[0-9]{3} - (GET|POST|PUT|DELETE)/) {
                print CYAN $0 NC

            # 8. Default/Continuation Lines
            } else {
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

kh() {
    echo -e "\n\033[1;33m🔍 Kubernetes Health Check\033[0m"

    echo -e "\n\033[1;36m1. Node Status (Kubelet)\033[0m"
    command kubectl get nodes -o wide

    echo -e "\n\033[1;36m2. Node Resources\033[0m"
    if command kubectl top nodes &> /dev/null; then
        command kubectl top nodes
    else
        echo "⚠️  Metrics API not available (metrics-server might be missing)"
    fi

    echo -e "\n\033[1;36m3. Control Plane Components\033[0m"
    # Check pods in kube-system
    command kubectl get pods -n kube-system -o wide | grep -E 'etcd|kube-apiserver|kube-controller-manager|kube-scheduler|coredns' || echo "No control plane pods visible in kube-system"

    echo -e "\n\033[1;36m4. Pod Health (Global - Non-Running)\033[0m"
    PROBLEMS=$(command kubectl get pods -A --no-headers 2>/dev/null | grep -vE 'Running|Completed')
    if [[ -z "$PROBLEMS" ]]; then
        echo "✅ All pods are healthy"
    else
        echo "$PROBLEMS" | head -n 10 | awk 'BEGIN {printf "%-20s %-30s %-10s %-20s %-10s %-10s\n", "NAMESPACE", "NAME", "READY", "STATUS", "RESTARTS", "AGE"} {printf "%-20s %-30s %-10s %-20s %-10s %-10s\n", $1, $2, $3, $4, $5, $6}'
        if [[ $(echo "$PROBLEMS" | wc -l) -gt 10 ]]; then echo "...and more"; fi
    fi

    echo -e "\n\033[1;36m5. Deployment Health (Global - Not Ready)\033[0m"
    DEPLOYS=$(command kubectl get deploy -A --no-headers 2>/dev/null | awk '{split($3,a,"/"); if(a[1]!=a[2]) print $0}')
    if [[ -z "$DEPLOYS" ]]; then
        echo "✅ All deployments are ready"
    else
        echo "$DEPLOYS" | awk 'BEGIN {printf "%-20s %-30s %-10s %-10s %-10s %-10s\n", "NAMESPACE", "NAME", "READY", "UP-TO-DATE", "AVAILABLE", "AGE"} {printf "%-20s %-30s %-10s %-10s %-10s %-10s\n", $1, $2, $3, $4, $5, $6}'
    fi

    echo -e "\n\033[1;36m6. Services (Namespace: $LAST_K8S_NAMESPACE)\033[0m"
    command kubectl get svc -n "$LAST_K8S_NAMESPACE" 2>/dev/null || echo "No services found in $LAST_K8S_NAMESPACE"
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
