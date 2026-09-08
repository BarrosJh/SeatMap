import { Router } from 'express';
import { scimAuth } from '../middleware/scimAuth';
import { ScimController } from '../controllers/scimController';
import { validateRequest } from '../middleware/validateRequest';
import { idParamSchema, scimListQuerySchema, scimPatchSchema, scimUserSchema } from '../schemas';

const router = Router();

// Discovery Endpoint
router.get('/ServiceProviderConfig', ScimController.getServiceProviderConfig);

// All user provisioning endpoints protected by SCIM Bearer token
router.use(scimAuth);

router.get('/Users', validateRequest({ query: scimListQuerySchema }), ScimController.getUsers);
router.get('/Users/:id', validateRequest({ params: idParamSchema }), ScimController.getUserById);
router.post('/Users', validateRequest({ body: scimUserSchema }), ScimController.createUser);
router.put('/Users/:id', validateRequest({ params: idParamSchema, body: scimUserSchema }), ScimController.updateUser);
router.patch('/Users/:id', validateRequest({ params: idParamSchema, body: scimPatchSchema }), ScimController.patchUser);
router.delete('/Users/:id', validateRequest({ params: idParamSchema }), ScimController.deleteUser);

export default router;

