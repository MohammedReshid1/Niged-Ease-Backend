#type:ignore

from decimal import Decimal
from django.http import Http404
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.request import Request
from drf_spectacular.utils import extend_schema, OpenApiResponse
from inventory.models.inventory import Inventory
from companies.models.store import Store
from inventory.models.product import Product
from inventory.serializers.product import ProductSerializer
import os

class ProductListView(APIView):
    @extend_schema(
        description="Get a list of all products for a specific store",
        responses={200: ProductSerializer(many=True)}
    )
    def get(self, request: Request, store_id):
        products = Product.objects.filter(store_id_id=store_id)
        serializer = ProductSerializer(products, many=True)
        return Response(data=serializer.data, status=status.HTTP_200_OK)
    
    @extend_schema(
        description="Create a new product and initialize inventory for the store",
        request=ProductSerializer,
        responses={
            201: ProductSerializer,
            400: OpenApiResponse(description="Invalid data"),
            403: OpenApiResponse(description="Subscription limit reached")
        }
    )
    def post(self, request: Request, store_id):
        try:
            store = Store.objects.get(pk=store_id)
            company = store.company_id
            current_product_count = Product.objects.filter(store_id__company_id=company).count()
            
            if current_product_count >= company.subscription_plan.max_products:# type: ignore
                return Response(
                    {
                        'error': 'Subscription product limit reached',
                        'current_count': current_store_count,
                        'max_allowed': company.subscription_plan.max_products if company.subscription_plan else 0
                    },
                    status=status.HTTP_403_FORBIDDEN
                )
            
            # Add store_id to request data
            request.data['store_id'] = store_id
            serializer = ProductSerializer(data=request.data)
            if serializer.is_valid():
                product = serializer.save()
                Inventory.objects.create(
                    product=product,
                    store=store,
                    quantity=Decimal('0')
                )
                return Response(data=serializer.data, status=status.HTTP_201_CREATED)
            return Response(data=serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
        except Store.DoesNotExist:
            raise Http404


class ProductDetailView(APIView):
    def get_product(self, id, store_id):
        try:
            product = Product.objects.get(pk=id, store_id=store_id)
            return product
        except Product.DoesNotExist:
            raise Http404
    
    @extend_schema(
        description="Get a specific product by ID for a specific store",
        responses={
            200: ProductSerializer,
            404: OpenApiResponse(description="Product not found")
        }
    )
    def get(self, request: Request, id, store_id):
        product = self.get_product(id, store_id)
        serializer = ProductSerializer(product)
        return Response(data=serializer.data, status=status.HTTP_200_OK)

    @extend_schema(
        description="Update a product for a specific store",
        request=ProductSerializer,
        responses={
            200: ProductSerializer,
            400: OpenApiResponse(description="Invalid data"),
            404: OpenApiResponse(description="Product not found")
        }
    )
    def put(self, request: Request, id, store_id):
        product = self.get_product(id, store_id)
        request.data['store_id'] = store_id
        print('product', product)
        serializer = ProductSerializer(product, data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(data=serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @extend_schema(
        description="Delete a product for a specific store",
        responses={
            204: OpenApiResponse(description="Product deleted successfully"),
            404: OpenApiResponse(description="Product not found")
        }
    )
    def delete(self, request: Request, id, store_id):
        product = self.get_product(id, store_id)
        product.delete()
        import requests
        
        requests.post(os.getenv('USER_SERVICE_URL') + '/activity-logs/', json={
            "user": request.user.id,
            'action': 'deleted product',
            'description': 'deleted product with id ' + str(id),
        },  headers={'Authorization': request.headers.get('Authorization')})

        return Response({'message': 'Product deleted successfully'}, status=status.HTTP_204_NO_CONTENT)