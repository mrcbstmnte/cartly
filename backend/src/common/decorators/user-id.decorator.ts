import {
  createParamDecorator,
  ExecutionContext,
  InternalServerErrorException,
} from '@nestjs/common';
import { AuthenticatedRequest } from '../types/authenticated-request';

export const UserId = createParamDecorator(
  (_data: unknown, context: ExecutionContext): string => {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();

    if (!request.userId) {
      // Unreachable while UserIdGuard is registered globally. Loud failure
      // beats silently serving one user another user's data.
      throw new InternalServerErrorException('UserIdGuard did not run');
    }

    return request.userId;
  },
);
