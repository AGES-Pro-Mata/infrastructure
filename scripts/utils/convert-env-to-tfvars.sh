#!/bin/bash
# Convert .env file to terraform.tfvars format

input_file="$1"
output_file="$2"

if [[ ! -f "$input_file" ]]; then
    echo "Error: Input file $input_file not found"
    exit 1
fi

echo "# Generated from $input_file" > "$output_file"
echo "# $(date)" >> "$output_file"
echo "" >> "$output_file"

while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^#.*$ ]] && continue
    [[ -z "$key" ]] && continue
    
    # Remove quotes and convert to lowercase for terraform
    key=$(echo "$key" | tr '[:upper:]' '[:lower:]')
    value=$(echo "$value" | sed 's/^"//' | sed 's/"$//')
    
    echo "$key = \"$value\"" >> "$output_file"
done < "$input_file"

echo "Converted $input_file to $output_file"
