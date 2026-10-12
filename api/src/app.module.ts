import { Module } from '@nestjs/common';

import { AppConfigModule } from './config/config.module';
import { JourneysModule } from './journeys/journeys.module';
import { PlacesModule } from './places/places.module';
import { ProviderGatewayModule } from './provider-gateway/provider-gateway.module';
import { DatabaseModule } from './shared/database/database.module';
import { HealthModule } from './shared/health/health.module';
import { TransitModule } from './transit/transit.module';
import { IdentityModule } from './identity/identity.module';
import { FavoritesModule } from './favorites/favorites.module';
import { CommutesModule } from './commutes/commutes.module';
import { AlertsModule } from './alerts/alerts.module';
import { NotificationsModule } from './notifications/notifications.module';
import { ActiveJourneysModule } from './active-journeys/active-journeys.module';
import { WorkerModule } from './worker/worker.module';

@Module({
  imports: [
    AppConfigModule,
    DatabaseModule,
    HealthModule,
    ProviderGatewayModule,
    PlacesModule,
    TransitModule,
    JourneysModule,
    IdentityModule,
    FavoritesModule,
    CommutesModule,
    AlertsModule,
    NotificationsModule,
    ActiveJourneysModule,
    WorkerModule,
  ],
})
export class AppModule {}
