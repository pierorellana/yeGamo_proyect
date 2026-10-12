import { Injectable, UnauthorizedException } from '@nestjs/common';

import { PrismaService } from '../../shared/database/prisma.service';
import { ExternalPrincipal, UserPreferencesRecord, UserRecord, UserRepository } from '../domain/identity.ports';

@Injectable()
export class PrismaUserRepository implements UserRepository {
  constructor(private readonly prisma: PrismaService) {}

  async upsertPrincipal(principal: ExternalPrincipal): Promise<UserRecord> {
    const existing = await this.prisma.user.findUnique({ where: { issuer_subject: { issuer: principal.issuer, subject: principal.subject } } });
    if (existing !== null && existing.deletedAt !== null) throw new UnauthorizedException({ code: 'UNAUTHORIZED', message: 'La cuenta ya no está disponible.', details: { identity: 'DELETED' } });
    const user = existing === null
      ? await this.prisma.user.create({ data: { issuer: principal.issuer, subject: principal.subject, email: principal.email, displayName: principal.displayName } })
      : await this.prisma.user.update({ where: { id: existing.id }, data: { email: principal.email, displayName: principal.displayName } });
    return toUserRecord(user);
  }

  async getById(userId: string): Promise<UserRecord | null> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    return user === null ? null : toUserRecord(user);
  }

  async getPreferences(userId: string): Promise<UserPreferencesRecord> {
    const preferences = await this.prisma.userPreference.upsert({
      where: { userId },
      create: { userId },
      update: {},
    });
    return toPreferences(preferences);
  }

  async updatePreferences(userId: string, input: Partial<UserPreferencesRecord>): Promise<UserPreferencesRecord> {
    const preferences = await this.prisma.userPreference.upsert({
      where: { userId },
      create: { userId, ...toPrismaPreferences(input) },
      update: toPrismaPreferences(input),
    });
    return toPreferences(preferences);
  }

  async hasLocationConsent(userId: string): Promise<boolean> {
    const preferences = await this.prisma.userPreference.findUnique({ where: { userId } });
    return preferences?.locationHistoryConsent === true;
  }

  async deleteAccount(userId: string): Promise<void> {
    await this.prisma.user.update({ where: { id: userId }, data: { deletedAt: new Date() } });
  }
}

function toUserRecord(user: { id: string; issuer: string; subject: string; email: string | null; displayName: string | null; createdAt: Date }): UserRecord {
  return { id: user.id, issuer: user.issuer, subject: user.subject, email: user.email, displayName: user.displayName, createdAt: user.createdAt };
}

function toPreferences(value: { language: string; travelPreference: string; maxWalkMin: number; extraSafetyMarginMin: number; locationHistoryConsent: boolean }): UserPreferencesRecord {
  return { language: value.language, defaultPreference: value.travelPreference, maxWalkMin: value.maxWalkMin, extraSafetyMarginMin: value.extraSafetyMarginMin, locationConsent: value.locationHistoryConsent };
}

function toPrismaPreferences(input: Partial<UserPreferencesRecord>): Record<string, unknown> {
  return {
    ...(input.language === undefined ? {} : { language: input.language }),
    ...(input.defaultPreference === undefined ? {} : { travelPreference: input.defaultPreference }),
    ...(input.maxWalkMin === undefined ? {} : { maxWalkMin: input.maxWalkMin }),
    ...(input.extraSafetyMarginMin === undefined ? {} : { extraSafetyMarginMin: input.extraSafetyMarginMin }),
    ...(input.locationConsent === undefined ? {} : { locationHistoryConsent: input.locationConsent }),
  };
}
