#!/bin/bash
# Audit script to identify unused/unreferenced scripts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔍 Auditing scripts for usage across the project..."
echo "================================================="

# Array to track used scripts
declare -A referenced_scripts
declare -A script_locations

# Find all shell scripts
while IFS= read -r -d '' script; do
    script_name=$(basename "$script")
    script_locations["$script_name"]="$script"
done < <(find "$PROJECT_ROOT/scripts" -name "*.sh" -type f -print0)

echo "📊 Found ${#script_locations[@]} scripts to analyze"
echo ""

# Function to check if script is referenced
check_references() {
    local script_name="$1"
    local script_path="$2"
    local ref_count=0
    
    # Check in Makefile
    if grep -q "$script_name\|${script_path#$PROJECT_ROOT/}" "$PROJECT_ROOT/Makefile" 2>/dev/null; then
        ((ref_count++))
        echo "  ✅ Referenced in Makefile"
    fi
    
    # Check in GitHub workflows
    if find "$PROJECT_ROOT/.github/workflows" -name "*.yml" -exec grep -l "$script_name\|${script_path#$PROJECT_ROOT/}" {} \; 2>/dev/null | head -1 >/dev/null; then
        ((ref_count++))
        echo "  ✅ Referenced in GitHub workflows"
    fi
    
    # Check in other scripts
    if find "$PROJECT_ROOT/scripts" -name "*.sh" ! -path "$script_path" -exec grep -l "$script_name\|${script_path#$PROJECT_ROOT/}" {} \; 2>/dev/null | head -1 >/dev/null; then
        ((ref_count++))
        echo "  ✅ Referenced in other scripts"
    fi
    
    # Check in documentation
    if find "$PROJECT_ROOT" -name "*.md" -exec grep -l "$script_name\|${script_path#$PROJECT_ROOT/}" {} \; 2>/dev/null | head -1 >/dev/null; then
        ((ref_count++))
        echo "  ✅ Referenced in documentation"
    fi
    
    # Check in Ansible playbooks
    if find "$PROJECT_ROOT/ansible" -name "*.yml" -exec grep -l "$script_name\|${script_path#$PROJECT_ROOT/}" {} \; 2>/dev/null | head -1 >/dev/null; then
        ((ref_count++))
        echo "  ✅ Referenced in Ansible playbooks"
    fi
    
    return $ref_count
}

# Arrays for categorization
declare -a essential_scripts
declare -a referenced_scripts_list
declare -a unreferenced_scripts
declare -a duplicate_scripts

echo "🔍 Analyzing each script..."
echo "=========================="

for script_name in "${!script_locations[@]}"; do
    script_path="${script_locations[$script_name]}"
    echo ""
    echo "📄 $script_name"
    echo "   Location: ${script_path#$PROJECT_ROOT/}"
    
    # Check for references
    if check_references "$script_name" "$script_path"; then
        ref_count=$?
        if [ $ref_count -gt 0 ]; then
            referenced_scripts_list+=("$script_name")
            echo "   📊 Reference count: $ref_count"
        else
            unreferenced_scripts+=("$script_name")
            echo "   ⚠️  No references found"
        fi
    else
        unreferenced_scripts+=("$script_name")
        echo "   ⚠️  No references found"
    fi
    
    # Check if it's an essential script (newly created or core functionality)
    if [[ "$script_name" == "vault-easy.sh" ]] || \
       [[ "$script_name" == "import-existing-ips.sh" ]] || \
       [[ "$script_name" == "setup-shared-state.sh" ]] || \
       [[ "$script_name" == "remove-deprecated-files.sh" ]] || \
       [[ "$script_name" == "cleanup-unused-envs.sh" ]]; then
        essential_scripts+=("$script_name")
        echo "   🌟 ESSENTIAL (newly implemented)"
    fi
done

# Find duplicates by checking for similar names
echo ""
echo "🔍 Checking for duplicate functionality..."
echo "========================================"

declare -A similar_groups
similar_groups["backup"]=""
similar_groups["deploy"]=""
similar_groups["setup"]=""
similar_groups["security"]=""
similar_groups["test"]=""
similar_groups["terraform"]=""

for script_name in "${!script_locations[@]}"; do
    for group in "${!similar_groups[@]}"; do
        if [[ "$script_name" == *"$group"* ]]; then
            similar_groups["$group"]+="$script_name "
        fi
    done
done

for group in "${!similar_groups[@]}"; do
    if [[ -n "${similar_groups[$group]}" ]]; then
        count=$(echo "${similar_groups[$group]}" | wc -w)
        if [ $count -gt 1 ]; then
            echo "📦 $group group ($count scripts): ${similar_groups[$group]}"
        fi
    fi
done

# Generate report
echo ""
echo "📋 AUDIT REPORT"
echo "==============="
echo ""

echo "🌟 ESSENTIAL SCRIPTS (${#essential_scripts[@]}):"
for script in "${essential_scripts[@]}"; do
    echo "  ✅ $script"
done
echo ""

echo "📚 REFERENCED SCRIPTS (${#referenced_scripts_list[@]}):"
for script in "${referenced_scripts_list[@]}"; do
    if [[ ! " ${essential_scripts[@]} " =~ " ${script} " ]]; then
        echo "  📄 $script"
    fi
done
echo ""

echo "⚠️  UNREFERENCED SCRIPTS (${#unreferenced_scripts[@]}):"
if [ ${#unreferenced_scripts[@]} -eq 0 ]; then
    echo "  🎉 None found!"
else
    for script in "${unreferenced_scripts[@]}"; do
        script_path="${script_locations[$script]}"
        echo "  🗑️  $script"
        echo "      ${script_path#$PROJECT_ROOT/}"
        
        # Quick heuristic to determine if it might be safe to remove
        if [[ "$script" == *"test"* ]] || [[ "$script" == *"backup"* ]] && [[ "$script" != *"restore"* ]]; then
            echo "      💡 Likely safe to archive"
        elif [[ "$script" == *"old"* ]] || [[ "$script" == *"legacy"* ]] || [[ "$script" == *"deprecated"* ]]; then
            echo "      💡 Definitely safe to remove"
        fi
    done
fi

echo ""
echo "🎯 RECOMMENDATIONS:"
echo "=================="
echo ""
echo "1. ✅ Keep all ESSENTIAL scripts (core new functionality)"
echo "2. 📚 Keep all REFERENCED scripts (actively used)"
echo "3. 🗂️  Archive UNREFERENCED scripts to envs/archive/scripts/"
echo "4. 🔍 Review similar-named scripts for consolidation opportunities"
echo ""

# Generate cleanup script
cat > "$PROJECT_ROOT/scripts/cleanup/cleanup-unreferenced-scripts.sh" << 'EOF'
#!/bin/bash
# Generated cleanup script for unreferenced scripts
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
ARCHIVE_DIR="$PROJECT_ROOT/envs/archive/scripts"

echo "🗂️  Archiving unreferenced scripts..."
mkdir -p "$ARCHIVE_DIR"

EOF

if [ ${#unreferenced_scripts[@]} -gt 0 ]; then
    echo "# Unreferenced scripts found on $(date)" >> "$PROJECT_ROOT/scripts/cleanup/cleanup-unreferenced-scripts.sh"
    for script in "${unreferenced_scripts[@]}"; do
        script_path="${script_locations[$script]}"
        echo "echo \"Archiving $script...\"" >> "$PROJECT_ROOT/scripts/cleanup/cleanup-unreferenced-scripts.sh"
        echo "mv \"$script_path\" \"\$ARCHIVE_DIR/\"" >> "$PROJECT_ROOT/scripts/cleanup/cleanup-unreferenced-scripts.sh"
    done
else
    echo "echo \"No unreferenced scripts found!\"" >> "$PROJECT_ROOT/scripts/cleanup/cleanup-unreferenced-scripts.sh"
fi

echo "" >> "$PROJECT_ROOT/scripts/cleanup/cleanup-unreferenced-scripts.sh"
echo "echo \"✅ Cleanup completed!\"" >> "$PROJECT_ROOT/scripts/cleanup/cleanup-unreferenced-scripts.sh"

chmod +x "$PROJECT_ROOT/scripts/cleanup/cleanup-unreferenced-scripts.sh"

echo "💡 Generated cleanup script: scripts/cleanup/cleanup-unreferenced-scripts.sh"
echo "    Run it to archive unreferenced scripts safely"