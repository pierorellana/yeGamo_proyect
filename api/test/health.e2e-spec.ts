import {
  Body,
  Controller,
  INestApplication,
  Post,
} from '@nestjs/common';
import { IsNotEmpty, IsString } from 'class-validator';
import { Test as NestTest } from '@nestjs/testing';
import request from 'supertest';

import { configureApp } from '../src/app.bootstrap';
import { AppModule } from '../src/app.module';

class ValidationProbeDto {
  @IsString()
  @IsNotEmpty()
  value!: string;
}

@Controller('test-validation')
class ValidationProbeController {
  @Post()
  post(@Body() body: ValidationProbeDto): ValidationProbeDto {
    return body;
  }
}

describe('API bootstrap', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await NestTest.createTestingModule({
      imports: [AppModule],
      controllers: [ValidationProbeController],
    }).compile();

    app = configureApp(moduleRef.createNestApplication());
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns the canonical health response and trace header', async () => {
    await request(app.getHttpServer())
      .get('/v1/health')
      .set('X-Trace-Id', 'e2e-health-trace')
      .expect(200)
      .expect('X-Trace-Id', 'e2e-health-trace')
      .expect(({ body }) => {
        expect(body).toEqual({
          status: 'ok',
          version: '1.1.1',
          traceId: 'e2e-health-trace',
        });
      });
  });

  it('rejects unknown fields using the canonical error shape', async () => {
    await request(app.getHttpServer())
      .post('/v1/test-validation')
      .send({ value: 'ok', unexpected: true })
      .expect(422)
      .expect('Content-Type', /json/)
      .expect(({ body, headers }) => {
        expect(headers['x-trace-id']).toEqual(body.traceId);
        expect(body).toMatchObject({
          code: 'VALIDATION_ERROR',
          message: expect.any(String),
          details: {
            validationErrors: expect.arrayContaining([
              expect.objectContaining({ property: 'unexpected' }),
            ]),
          },
          traceId: expect.any(String),
        });
      });
  });
});
