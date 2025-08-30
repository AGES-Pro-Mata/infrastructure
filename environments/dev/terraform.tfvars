# Terraform variables for Pro-Mata Development Environment

# SSH public key for VM access (required)
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiS7dgX/VwxqGEy3B5Vhi7UXBM1SAUN4atLc8kbWGEGGieqsBmFdK/q0apujyI0tII1zpd1kFBnrE8IMlGe19icWZ0bjiX6wh90lRz9MkfQ1aD36F6IL/U38/CSvnFOK7H7Csp0ROVvV74nniUleYHdVR9u/BhLuwbMZBSmRFfpiuzzytPczVmuT9HgHiqtHXZt5v+r6vNTkTlINs8DH52CrGRqHSo0/jQgsfWx0wwZLAhRL/x3T9nk7+o8AlrueA+YTRklx/UJqLnkcnEH7XIOG5Am3TTgZez/SkOAoskjBLI+GZbiXmQHq3/+UtINNsOmMRcrrg5p0H2Wx2RTSc5MiCkIt702Nahu5pguifyLPaQayszGnC/jRe8sM/PQRSXB7VwM2R898L9kPJ9JsC/YGwwrWCFBxPjZr+bFF008Z65JTmb16cqFzllpRWnWm/sqti55e/C+sFjyFYN47sTGlKmDvr5y7XEKRq9YqDmVc5XF1OZ/PsefKzdZZb3V/vThl2WLUhgsv5BZupyI9PoTU48e5aAWxPgYh5rzNn1PqTgS5fyUEkMgjpm2XSwyta1uUbnsF+XgMcatTPBOjhh3hieDNa/lkjDXPfypgtHHyX9jbcgTth9lcDDcduQN9/lsSGCoPQOrVS6gDoTTqh0N3FuMLJ0lffuuRKMaAB1eQ== promata-azure-dev"

# Storage account name (must be globally unique)
storage_account_name = "promatadevstore64300"

# Override any default values if needed
# resource_group_name = "rg-promata-dev"
# location = "East US 2"
# vm_size = "Standard_B2s"
# domain_name = "promata-dev.duckdns.org"