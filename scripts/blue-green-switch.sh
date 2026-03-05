#!/bin/bash

CURRENT=$(kubectl get svc backend-service -n ecommerce-prod -o jsonpath='{.spec.selector.slot}')
echo "Current active slot: $CURRENT"

if [ "$CURRENT" == "blue" ]; then
  NEW_SLOT="green"
else
  NEW_SLOT="blue"
fi

echo "Switching to: $NEW_SLOT"
kubectl patch svc backend-service -n ecommerce-prod \
  -p "{\"spec\":{\"selector\":{\"app\":\"backend\",\"slot\":\"$NEW_SLOT\"}}}"

echo "Traffic now routed to slot: $NEW_SLOT"