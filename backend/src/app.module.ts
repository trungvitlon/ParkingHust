import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { ParkingLotsModule } from './parking-lots/parking-lots.module';
import { ParkingPassModule } from './parking-pass/parking-pass.module';
import { AuthModule } from './auth/auth.module';

@Module({
  imports: [PrismaModule, ParkingLotsModule, ParkingPassModule, AuthModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}