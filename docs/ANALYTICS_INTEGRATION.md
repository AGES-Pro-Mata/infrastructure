# Analytics Integration Guide - Umami & Metabase

## 📊 Overview

This guide explains how to properly configure Umami analytics and Metabase BI integration in the Pro-Mata infrastructure.

## 🔧 Umami Configuration

### 1. Frontend Integration

The frontend automatically includes Umami tracking when these environment variables are set:

```env
VITE_UMAMI_URL=https://analytics.your-domain.com
VITE_UMAMI_WEBSITE_ID=your-website-id
VITE_ENABLE_ANALYTICS=true
```

**Frontend Code Integration (React/Vite):**

Add to your main app component or index.html:
```jsx
// In your React app (src/main.tsx or App.tsx)
import { useEffect } from 'react';

export default function App() {
  useEffect(() => {
    if (import.meta.env.VITE_ENABLE_ANALYTICS === 'true') {
      // Umami tracking script
      const script = document.createElement('script');
      script.async = true;
      script.defer = true;
      script.setAttribute('data-website-id', import.meta.env.VITE_UMAMI_WEBSITE_ID);
      script.src = `${import.meta.env.VITE_UMAMI_URL}/script.js`;
      document.head.appendChild(script);
    }
  }, []);

  return (
    // Your app content
  );
}
```

### 2. Backend Integration (Optional)

For server-side event tracking:

```typescript
// In your NestJS backend
import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';

@Injectable()
export class AnalyticsService {
  constructor(private httpService: HttpService) {}

  async trackEvent(eventData: {
    url: string;
    event_name: string;
    event_data?: any;
  }) {
    if (process.env.ENABLE_ANALYTICS !== 'true') return;

    try {
      await this.httpService.post(`${process.env.UMAMI_URL}/api/send`, {
        type: 'event',
        payload: {
          website: process.env.UMAMI_WEBSITE_ID,
          ...eventData
        }
      }, {
        headers: {
          'Authorization': `Bearer ${process.env.UMAMI_API_KEY}`
        }
      }).toPromise();
    } catch (error) {
      console.error('Analytics tracking error:', error);
    }
  }
}
```

## 🏗️ Infrastructure Setup

### 1. Deploy Analytics Stack

```bash
# Deploy analytics services
docker stack deploy -c docker/stacks/analytics-stack.yml promata-analytics

# Verify deployment
docker service ls | grep analytics
```

### 2. Configure Environment Variables

Update your environment configuration:

**For Development (`envs/dev/ansible-vars.yml`):**
```yaml
enable_analytics: "true"
umami_website_id: "dev-website-id"
umami_hash_salt: "random-salt-string"
umami_db_password: "secure-password"
```

**For Production (`envs/prod/ansible-vars.yml`):**
```yaml
enable_analytics: "true"
umami_website_id: "prod-website-id"
umami_hash_salt: "different-random-salt"
umami_db_password: "very-secure-password"
```

### 3. Umami Initial Setup

1. **Access Umami Dashboard:**
   - Dev: `https://analytics.dev.promata.com.br`
   - Prod: `https://analytics.promata.com.br`

2. **Default Login:**
   - Username: `admin`
   - Password: `umami`
   - **⚠️ Change immediately after first login**

3. **Create Website:**
   - Add your domain(s)
   - Copy the generated Website ID
   - Update ansible vars with the Website ID

### 4. DNS and Traefik Setup

Ensure your DNS points to the infrastructure and Traefik is configured:

```yaml
# traefik routes (automatically configured by analytics-stack.yml)
- traefik.http.routers.umami.rule=Host(`analytics.${DOMAIN_NAME}`)
- traefik.http.routers.metabase.rule=Host(`bi.${DOMAIN_NAME}`)
```

## 📈 Metabase Configuration

### 1. Initial Setup

1. **Access Metabase:**
   - Dev: `https://bi.dev.promata.com.br`
   - Prod: `https://bi.promata.com.br`

2. **Database Connection:**
   - Type: PostgreSQL
   - Host: `pgbouncer` (connection pooled)
   - Port: `6432`
   - Database: `promata_dev` or `promata_prod`
   - Username: Use your PostgreSQL user
   - Password: Use your PostgreSQL password

### 2. Analytics Database Integration

To analyze Umami data in Metabase:

1. **Add Umami Database:**
   - Host: `umami-db`
   - Port: `5432`
   - Database: `umami`
   - Username: `umami`

2. **Create Cross-Database Queries:**
   - Join user behavior from Umami with application data
   - Create comprehensive dashboards

## 🔍 Monitoring and Troubleshooting

### Health Checks

```bash
# Check service health
docker service ps promata-analytics_umami
docker service ps promata-analytics_metabase

# View logs
docker service logs promata-analytics_umami
docker service logs promata-analytics_metabase
```

### Common Issues

1. **Umami not tracking:**
   - Verify `VITE_UMAMI_WEBSITE_ID` is set correctly
   - Check browser console for script loading errors
   - Ensure analytics.domain.com is accessible

2. **Metabase connection issues:**
   - Verify pgbouncer is running and accessible
   - Check database credentials
   - Ensure networks are properly configured

3. **DNS/SSL Issues:**
   - Verify Traefik configuration
   - Check Let's Encrypt certificate generation
   - Ensure DNS propagation is complete

## 🚀 Deployment Commands

```bash
# Deploy full stack with analytics
make deploy-dev     # For development
make deploy-prod    # For production

# Deploy only analytics
docker stack deploy -c docker/stacks/analytics-stack.yml promata-analytics

# Update app stack with analytics config
docker stack deploy -c docker/stacks/app-stack.yml promata-app
```

## ✅ Verification Checklist

- [ ] Umami dashboard accessible
- [ ] Website tracking configured
- [ ] Frontend includes tracking script
- [ ] Backend analytics service implemented (optional)
- [ ] Metabase dashboard accessible  
- [ ] Database connections working
- [ ] SSL certificates valid
- [ ] DNS resolution working
- [ ] Health checks passing