import { Module } from '@nestjs/common';
import { ParkingPassService } from './parking-pass.service';
import { ParkingPassController } from './parking-pass.controller';

@Module({
  controllers: [ParkingPassController],
  providers: [ParkingPassService],
})
export class ParkingPassModule {}
