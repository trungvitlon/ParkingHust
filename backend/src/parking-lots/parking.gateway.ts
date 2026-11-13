import { WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server } from 'socket.io';

@WebSocketGateway({
  cors: {
    origin: '*', // Cho phép mọi thiết bị Mobile/Web kết nối
  },
})
export class ParkingGateway {
  @WebSocketServer()
  server: Server;

  // Hàm phát tín hiệu thông báo số chỗ trống vừa thay đổi cho tất cả máy điện thoại
  notifyParkingUpdated(lotId: string, message: string) {
    this.server.emit('parkingUpdated', {
      lotId,
      message,
      timestamp: new Date().toISOString(),
    });
  }

  // Phát tín hiệu Cảnh báo thông minh (Quá tải / Đóng cửa / Qua đêm)
  sendSmartAlert(alert: any) {
    this.server.emit('smartAlert', alert);
  }
}