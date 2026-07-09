#!/bin/bash
set -e

# Target directories
DIRS="upsilonapi upsilonbattle upsilonbattleui upsiloncli"

# Function to move atoms for a specific project
move_atoms() {
    local project=$1
    echo "Moving atoms to $project..."
    
    # Extract the block of atoms for the project from the transition document
    # Using awk to find the section and print the lines until the next code block or section
    awk -v proj="$project" '
        $0 ~ "#### " proj { flag=1; next }
        flag && /^```/ { count++; if(count==1) next; if(count==2) exit }
        flag && count==1 { if($1 != "") print $1 }
    ' upsilon-hub-transition.md > /tmp/${project}_atoms.txt
    
    # Move each atom
    while read -r atom; do
        if [ -f "docs/${atom}.atom.md" ]; then
            mv "docs/${atom}.atom.md" "${project}/docs/"
        else
            echo "Warning: docs/${atom}.atom.md not found!"
        fi
    done < /tmp/${project}_atoms.txt
}

# Move standard projects based on the document lists
for project in $DIRS; do
    move_atoms $project
done

# Move shared atoms to upsilonbattleui (as requested by user)
echo "Moving shared atoms to upsilonbattleui..."
cat << 'EOF' > /tmp/shared_atoms.txt
req_security
req_matchmaking
rule_password_policy
rule_progression
rule_friendly_fire
req_player_experience
spec_match_format
EOF

# Since these are prefixes or exact names in the shared atoms list, let's just move them by prefix
for prefix in $(cat /tmp/shared_atoms.txt); do
    mv docs/${prefix}*.atom.md upsilonbattleui/docs/ 2>/dev/null || true
done

# Move temp atoms to docs/trashed
echo "Moving temp atoms to docs/trashed..."
mv docs/temp*.atom.md docs/trashed/ 2>/dev/null || true

# Any remaining atoms in docs/ (new ones with go code) go to upsilonbattle as requested
echo "Moving remaining new atoms to upsilonbattle..."
find docs/ -maxdepth 1 -name "*.atom.md" -type f -exec mv {} upsilonbattle/docs/ \;

echo "Migration script completed."
