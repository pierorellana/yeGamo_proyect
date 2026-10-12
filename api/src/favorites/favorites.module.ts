import { Module } from '@nestjs/common';

import { IdentityModule } from '../identity/identity.module';
import { DatabaseModule } from '../shared/database/database.module';
import { FavoritesService } from './application/favorites.service';
import { FAVORITE_PLACES_REPOSITORY } from './domain/favorites.ports';
import { FavoritesController } from './http/favorites.controller';
import { PrismaFavoritePlacesRepository } from './infrastructure/prisma-favorites.repository';

@Module({
  imports: [DatabaseModule, IdentityModule],
  controllers: [FavoritesController],
  providers: [
    PrismaFavoritePlacesRepository,
    { provide: FAVORITE_PLACES_REPOSITORY, useExisting: PrismaFavoritePlacesRepository },
    FavoritesService,
  ],
  exports: [FavoritesService, FAVORITE_PLACES_REPOSITORY],
})
export class FavoritesModule {}
