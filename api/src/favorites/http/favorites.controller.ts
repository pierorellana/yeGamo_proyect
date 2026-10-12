import { Body, Controller, Delete, Get, Headers, HttpCode, HttpStatus, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { PrincipalAuthGuard, principalOf, AuthenticatedRequest } from '../../identity/http/auth.guard';
import { FavoritesService } from '../application/favorites.service';
import { FavoritePlaceDto, FavoritePlaceIdDto } from './favorites.dto';

@Controller('favorites/places')
@UseGuards(PrincipalAuthGuard)
export class FavoritesController {
  constructor(private readonly favorites: FavoritesService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest) { return this.favorites.list(principalOf(request).userId); }

  @Post()
  create(@Req() request: AuthenticatedRequest, @Body() body: FavoritePlaceDto, @Headers('idempotency-key') key: string | undefined) {
    return this.favorites.create(principalOf(request).userId, body, key);
  }

  @Patch(':id')
  update(@Req() request: AuthenticatedRequest, @Param() params: FavoritePlaceIdDto, @Body() body: FavoritePlaceDto) {
    return this.favorites.update(principalOf(request).userId, params.id, body);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  delete(@Req() request: AuthenticatedRequest, @Param() params: FavoritePlaceIdDto): Promise<void> {
    return this.favorites.delete(principalOf(request).userId, params.id);
  }
}
