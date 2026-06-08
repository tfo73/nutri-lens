const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const axios = require('axios');

// Secret tanımları
const anthropicKey = defineSecret('ANTHROPIC_API_KEY');
const usdaKey = defineSecret('USDA_API_KEY');
const edamamNutritionKey = defineSecret('EDAMAM_NUTRITION_KEY');
const edamamRecipeKey = defineSecret('EDAMAM_RECIPE_KEY');

// Claude Vision proxy
exports.analyzeFood = onCall(
  { secrets: [anthropicKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Giriş gerekli');
    }
    try {
      const response = await axios.post(
        'https://api.anthropic.com/v1/messages',
        request.data.payload,
        {
          headers: {
            'x-api-key': anthropicKey.value(),
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
        }
      );
      return response.data;
    } catch (e) {
      throw new HttpsError('internal', e.message);
    }
  }
);

// USDA proxy
exports.searchFood = onCall(
  { secrets: [usdaKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Giriş gerekli');
    }
    try {
      const response = await axios.get(
        'https://api.nal.usda.gov/fdc/v1/foods/search',
        {
          params: {
            api_key: usdaKey.value(),
            query: request.data.query,
            dataType: 'Foundation,SR Legacy,Survey (FNDDS)',
            pageSize: 5,
          },
        }
      );
      return response.data;
    } catch (e) {
      throw new HttpsError('internal', e.message);
    }
  }
);

// USDA besin detayı proxy
exports.getFoodDetail = onCall(
  { secrets: [usdaKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Giriş gerekli');
    }
    try {
      const response = await axios.get(
        `https://api.nal.usda.gov/fdc/v1/food/${request.data.fdcId}`,
        {
          params: {
            api_key: usdaKey.value(),
            nutrients: request.data.nutrients.join(','),
          },
        }
      );
      return response.data;
    } catch (e) {
      throw new HttpsError('internal', e.message);
    }
  }
);

// Edamam Nutrition proxy
exports.analyzeNutrition = onCall(
  { secrets: [edamamNutritionKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Giriş gerekli');
    }
    try {
      const [appId, appKey] = edamamNutritionKey.value().split(':');
      const response = await axios.post(
        'https://api.edamam.com/api/nutrition-details',
        request.data.payload,
        {
          params: {
            app_id: appId,
            app_key: appKey,
          },
        }
      );
      return response.data;
    } catch (e) {
      throw new HttpsError('internal', e.message);
    }
  }
);

// Edamam Recipe proxy
exports.searchRecipes = onCall(
  { secrets: [edamamRecipeKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Giriş gerekli');
    }
    try {
      const [appId, appKey] = edamamRecipeKey.value().split(':');
      const response = await axios.get(
        'https://api.edamam.com/api/recipes/v2',
        {
          params: {
            type: 'public',
            app_id: appId,
            app_key: appKey,
            q: request.data.query,
            mealType: request.data.mealType,
            health: request.data.health,
            to: request.data.limit ?? 10,
          },
        }
      );
      return response.data;
    } catch (e) {
      throw new HttpsError('internal', e.message);
    }
  }
);