# Staging Environment - DEPRECATED

## ⚠️ Status: DEPRECATED

This staging environment has been simplified and merged with the development workflow.

### New Environment Structure

- **Development (Azure)**: `envs/dev/` - Used for development and testing
- **Production (AWS)**: `envs/prod/` - Production deployment with static IPs

### Migration Notes

1. **Development Testing**: Use `envs/dev/` for all development and staging needs
2. **Production Deployment**: Direct deployment to `envs/prod/` after thorough testing in dev
3. **AWS Infrastructure**: Production uses static IPs provided by third party, with Terraform files as documentation

### Rationale

- **Simplified Workflow**: Reduces complexity and maintenance overhead
- **Cost Optimization**: Eliminates unnecessary staging environment costs
- **Clear Separation**: Dev (Azure) vs Prod (AWS) with distinct purposes
- **Flexibility**: Dev environment can be used for AWS testing once static IPs are available

For questions or migration assistance, refer to the main infrastructure documentation.