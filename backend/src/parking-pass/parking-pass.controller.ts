import { Controller, Get, Post, Query, Body } from '@nestjs/common';
import { ParkingPassService } from './parking-pass.service';

@Controller('parking-pass')
export class ParkingPassController {
  constructor(private readonly parkingPassService: ParkingPassService) {}

  @Get()
  getPass(@Query('userId') userId?: string) {
    return this.parkingPassService.getStudentPass(userId);
  }

  @Post('toggle')
  toggle(@Body() body: { userId?: string; parkingLotId?: string }) {
    return this.parkingPassService.toggleCheckIn(body?.userId, body?.parkingLotId);
  }

  @Get('notifications')
  getNotifications() {
    return this.parkingPassService.getNotifications();
  }

  @Post('simulate-alert')
  simulateAlert(@Body('type') type: 'CLOSING' | 'OVERNIGHT') {
    return this.parkingPassService.triggerSystemAlert(type || 'CLOSING');
  }
}