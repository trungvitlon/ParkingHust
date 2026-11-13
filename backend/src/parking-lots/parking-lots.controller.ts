import { Controller, Get, Param, Query } from '@nestjs/common';
import { ParkingLotsService } from './parking-lots.service';

@Controller('parking-lots')
export class ParkingLotsController {
  constructor(private readonly parkingLotsService: ParkingLotsService) {}

  // API 1: Lấy danh sách toàn bộ nhà xe: GET /parking-lots
  @Get()
  findAll() {
    return this.parkingLotsService.findAll();
  }

  // API mới: GET /parking-lots/:id/traffic?range=today|week
  @Get(':id/traffic')
  getTraffic(@Param('id') id: string, @Query('range') range?: string) {
    return this.parkingLotsService.getTrafficStats(id, range || 'today');
  }

  // API 2: Xem chi tiết 1 nhà xe theo ID: GET /parking-lots/:id
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.parkingLotsService.findOne(id);
  }
}