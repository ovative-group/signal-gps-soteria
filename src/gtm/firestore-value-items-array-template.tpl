// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

/**
 * @fileoverview sGTM variable tag that uses data from Firestore to calculate
 * individual item margins and adds them as an attribute to each item object
 * in the datalayer.
 * @see {@link https://developers.google.com/analytics/devguides/collection/ga4/reference/events?client_type=gtag#purchase_item}
 * @version 3.0.0
 */

const Firestore = require("Firestore");
const Promise = require("Promise");
const getEventData = require("getEventData");
const logToConsole = require("logToConsole");
const makeNumber = require("makeNumber");
const makeString = require("makeString");
const Math = require("Math");
const getType = require("getType");

/**
 * Update each item in the items array with a 'margin' property based on
 * Firestore data.
 * @param {!Array<!Object>} items - an array of items from the datalayer.
 * @returns {!Promise<!Array<!Object>>} A promise that resolves to an array of
 * items where each item has a 'margin' property added.
 */
function updateItemsWithMargins(items) {
  return Promise.all(
    items.map((item) => getFirestoreMargin(item))
  );
}

/**
 * Fetch the margin for a specific item from Firestore.
 * @param {!Object} item - an item from the datalayer.
 * @returns {!Promise<!Object>} A promise that resolves to the item object
 * with a 'margin' property added based on Firestore data.
 */
function getFirestoreMargin(item) {
  if (!item.item_id) {
    logToConsole("No item ID in item");
    return Promise.resolve(item);
  }

  const path = data.collectionId + "/" + item.item_id;

  // Mock API returns a function, whereas usual import is object.
  // This logic enables support for tests within the function. See
  // https://developers.google.com/tag-platform/tag-manager/server-side/api#mock
  let firestore = Firestore;
  if (getType(Firestore) === "function") {
    firestore = Firestore();
  }

  return firestore
    .read(path, { projectId: data.gcpProjectId })
    .then((fsDocument) => {
      item.margin = calculateMargin(item, fsDocument);
      return item;
    })
    .catch((error) => {
      logToConsole(
        "Error retrieving Firestore document `" + path + "`",
        error
      );
      return item;
    });
}

/**
 * Calculate the margin based on the configuration and Firestore data.
 * @param {!Object} item - an item from the datalayer.
 * @param {!Object} fsDocument - a Firestore document.
  * @returns {number} The calculated margin for the item.
 */
function calculateMargin(item, fsDocument) {
  const documentValue = makeNumber(fsDocument.data[data.valueField]);
  const quantity = item.hasOwnProperty("quantity") ? item.quantity : 1;

  switch (data.valueCalculation) {
    case "valueQuantity":
      return documentValue * quantity;
    case "returnRate":
      const returnRate = makeNumber(fsDocument.data[data.returnRateField]);
      return (1 - returnRate) * documentValue * quantity;
    case "valueWithDiscount":
      const discount = item.hasOwnProperty("discount") ? item.discount : 0;
      return (documentValue - discount) * quantity;
  }
  return 0; // Default to 0 if no matching calculation is found