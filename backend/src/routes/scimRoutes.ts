import { Router } from 'express';
import { scimAuth } from '../middleware/scimAuth';
import { ScimController } from '../controllers/scimController';

const router = Router();

// Discovery Endpoint
router.get('/ServiceProviderConfig', ScimController.getServiceProviderConfig);

// All user provisioning endpoints protected by SCIM Bearer token
router.use(scimAuth);

router.get('/Users', ScimController.getUsers);
router.get('/Users/:id', ScimController.getUserById);
router.post('/Users', ScimController.createUser);
router.put('/Users/:id', ScimController.updateUser);
router.patch('/Users/:id', ScimController.patchUser);
router.delete('/Users/:id', ScimController.deleteUser);

export default router;

