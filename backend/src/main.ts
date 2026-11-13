import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  // Bật CORS để Mobile App và Web có thể gọi API
  app.enableCors();
  
  await app.listen(process.env.PORT ?? 3000);
  console.log(`🚀 Backend đang chạy tại: http://localhost:3000`);
}
bootstrap();