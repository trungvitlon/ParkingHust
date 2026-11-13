import { Global, Module } from '@nestjs/common';
import { ParkingLotsService } from './parking-lots.service';
import { ParkingLotsController } from './parking-lots.controller';
import { ParkingGateway } from './parking.gateway';

@Global() // Đặt Global để ParkingPassService có thể gọi phát sóng dễ dàng
@Module({
  controllers: [ParkingLotsController],
  providers: [ParkingLotsService, ParkingGateway],
  exports: [ParkingGateway],
})
export class ParkingLotsModule {}