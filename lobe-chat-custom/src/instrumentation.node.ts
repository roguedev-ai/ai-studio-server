import { register } from '@lobechat/observability-otel/node'
import { version } from '../package.json';

// Skip observability registration during Docker builds to prevent memory issues
if (process.env.DOCKER !== 'true') {
  register({ version })
}
