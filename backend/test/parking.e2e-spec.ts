import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';

describe('Parking API (e2e)', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /parking-lots và GET /parking-lots/:id/traffic trả về dữ liệu chuẩn', async () => {
    const lotsRes = await request(app.getHttpServer())
      .get('/parking-lots')
      .expect(200);

    expect(Array.isArray(lotsRes.body)).toBe(true);
    expect(lotsRes.body.length).toBeGreaterThan(0);

    const firstLotId = lotsRes.body[0].id;

    const trafficRes = await request(app.getHttpServer())
      .get(`/parking-lots/${firstLotId}/traffic?range=today`)
      .expect(200);

    expect(trafficRes.body).toHaveProperty('totalIn');
    expect(trafficRes.body).toHaveProperty('totalOut');
    expect(trafficRes.body.hourly).toHaveLength(17);
  });

  it('GET /parking-lots/id-khong-ton-tai/traffic trả về 404', async () => {
    await request(app.getHttpServer())
      .get('/parking-lots/id-khong-ton-tai/traffic')
      .expect(404);
  });
});