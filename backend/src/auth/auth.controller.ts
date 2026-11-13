import { Controller, Post, Body, Get, Query } from '@nestjs/common';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() body: any) {
    return this.authService.register(body);
  }

  @Post('login')
  login(@Body() body: { account: string; password: string }) {
    return this.authService.login(body.account, body.password);
  }

  @Get('profile')
  getProfile(@Query('userId') userId?: string) {
    return this.authService.getProfile(userId);
  }
}