export const REPOSITORY_PORT = Symbol('REPOSITORY_PORT');

export interface RepositoryPort<TEntity, TId = string> {
  findById(id: TId): Promise<TEntity | null>;
}
