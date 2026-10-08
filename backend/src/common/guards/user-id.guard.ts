import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthenticatedRequest } from '../types/authenticated-request';

export const USER_ID_HEADER = 'x-user-id';

@Injectable()
export class UserIdGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();

    const raw = request.headers[USER_ID_HEADER];
    const userId = (Array.isArray(raw) ? raw[0] : raw)?.trim();

    if (!userId) {
      throw new UnauthorizedException(`${USER_ID_HEADER} header is required`);
    }

    request.userId = userId;
    return true;
  }
}
