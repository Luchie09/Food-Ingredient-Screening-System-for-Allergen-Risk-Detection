% Food Ingredient Screening System Knowledge Base 

:- discontiguous allergen/1, regulated_by/2,
                 framework/3, member_of/2, special_category/1, allergy_name/2, alias/2,
                 primary_ingredient/3, derived_from/2, made_with/2,
                 refined_from/2, ambiguous_ingredient/2,
                 known_ingredient/1.


% Food Allergens regulatory identified from the recognized frameworks (EU, USA, Codex, Philippines)
allergen(milk).
allergen(egg).
allergen(fish).
allergen(crustacean_shellfish).
allergen(tree_nuts).
allergen(peanut).
allergen(wheat).
allergen(soy).
allergen(sesame).
allergen(gluten_containing_cereals).
allergen(celery).
allergen(mustard).
allergen(sulfites).
allergen(lupin).
allergen(molluscs).


% Framework regulatory for food allergens, framework(Id, Scope, Binding)
framework(us, national, mandatory).
framework(eu, regional, mandatory).
framework(ph, national, mandatory).
framework(codex, international_standard, voluntary_adoption).

% Food Allergens regulated by framework, regulated_by(Label, [Frameworks])
% Only frameworks with a mandatory provision are listed, a missing framework means not verified
regulated_by(milk, [us, eu, ph, codex]).
regulated_by(egg, [us, eu, ph, codex]).
regulated_by(fish, [us, eu, ph, codex]).
regulated_by(crustacean_shellfish, [us, eu, ph, codex]).
regulated_by(tree_nuts, [us, eu, ph, codex]).
regulated_by(peanut, [us, eu, ph, codex]).
regulated_by(wheat, [us, eu, ph, codex]).
regulated_by(soy, [us, eu, ph]).
regulated_by(sesame, [us, eu, codex]).
regulated_by(gluten_containing_cereals, [eu, ph, codex]).
regulated_by(celery, [eu]).
regulated_by(mustard, [eu]).
regulated_by(sulfites, [us, eu, ph, codex]).
regulated_by(lupin, [eu]).
regulated_by(molluscs, [eu]).

% member_of(Item, Category) is an item is named inside a broader labeling category
member_of(wheat, gluten_containing_cereals).

% special_category(Label) is a label reported separately from the food allergies
% It is a labeling or sensitivity category and not a diagnosis
special_category(gluten_containing_cereals).
special_category(sulfites).


% Associated allergy name of identified allergens
% Names for gluten_containing_cereals, celery, mustard, lupin and molluscs need verification
allergy_name(milk, ['Milk allergy']).
allergy_name(egg, ['Egg allergy']).
allergy_name(fish, ['Fish allergy']).
allergy_name(crustacean_shellfish, ['Crustacean shellfish allergy']).
allergy_name(tree_nuts, ['Tree-nut allergy']).
allergy_name(peanut, ['Peanut allergy']).
allergy_name(wheat, ['Wheat allergy']).
allergy_name(soy, ['Soy allergy']).
allergy_name(sesame, ['Sesame allergy']).
allergy_name(gluten_containing_cereals, ['Wheat allergy', 'Cereal grain allergy']).
allergy_name(celery, ['Celery allergy']).
allergy_name(mustard, ['Mustard allergy']).
allergy_name(sulfites, ['Sulfite sensitivity']).
allergy_name(lupin, ['Lupin allergy']).
allergy_name(molluscs, ['Mollusc allergy']).


% Allergy name aliases for converting alternative names to canonical names
% -Milk-
alias(cow_milk, milk).
alias(cows_milk, milk).
alias(dairy, milk).

% -Egg-
alias(eggs, egg).

% -Fish-
alias(finned_fish, fish).

% -Crustacean Shellfish-
alias(crustacean, crustacean_shellfish).
alias(crustaceans, crustacean_shellfish).

% -Tree Nuts-
alias(tree_nut, tree_nuts).
alias(nuts, tree_nuts).

% -Peanut-
alias(peanuts, peanut).
alias(groundnut, peanut).
alias(arachis, peanut).

% -Soy-
alias(soya, soy).
alias(soya_bean, soy).

% -Sesame-
alias(sesame_seeds, sesame).
alias(sesame_seed, sesame).

% -Gluten containing cereals-
alias(gluten_cereals, gluten_containing_cereals).
alias(cereals_containing_gluten, gluten_containing_cereals).

% -Sulfites-
alias(sulfite, sulfites).
alias(sulphite, sulfites).
alias(sulphites, sulfites).
alias(sulphur_dioxide, sulfites).

% Lupin
alias(lupine, lupin).

% -Molluscs-
alias(mollusc, molluscs).
alias(shellfish_mollusc, molluscs).

% -Natural Flavor-
alias(natural_flavors, natural_flavor).
alias(natural_flavour, natural_flavor).

% -Flavoring-
alias(flavorings, flavoring).

% -Vegetable_oil-
alias(vegetable_fat, vegetable_oil).

% -Hydrolyzed Vegetable Protein-
alias(hvp, hydrolyzed_vegetable_protein).


% Primary Allergen Ingredients
% These are ingredients that were directly associated with the allergen
% primary_ingredient(Ingredient, Label, Relationship)
% Relationship values:
%   is_allergen : the food is the allergen food
%   type_of     : a specific food classified under a specific allergen
%   part_of     : a natural part of the allergen food
%   contains    : a food that carries the allergen as a component

% -Milk-
primary_ingredient(milk, milk, is_allergen).
primary_ingredient(cream, milk, contains).
primary_ingredient(buttermilk, milk, contains).
primary_ingredient(cheese, milk, contains).
primary_ingredient(yogurt, milk, contains).
primary_ingredient(milk_powder, milk, contains).

% -Egg-
primary_ingredient(egg, egg, is_allergen).
primary_ingredient(egg_white, egg, part_of).
primary_ingredient(egg_yolk, egg, part_of).
% albumen (egg white) needs source confirmation
% albumin is under ambiguous ingredients because it can also come from non-egg sources
primary_ingredient(albumen, egg, contains).

% -Fish-
primary_ingredient(fish, fish, is_allergen).
primary_ingredient(cod, fish, type_of).
primary_ingredient(salmon, fish, type_of).
primary_ingredient(tuna, fish, type_of).
primary_ingredient(bass, fish, type_of).
primary_ingredient(flounder, fish, type_of).
primary_ingredient(mackerel, fish, type_of).
primary_ingredient(haddock, fish, type_of).

% -Crustacean Shellfish-
primary_ingredient(crustacean_shellfish, crustacean_shellfish, is_allergen).
primary_ingredient(crab, crustacean_shellfish, type_of).
primary_ingredient(lobster, crustacean_shellfish, type_of).
primary_ingredient(shrimp, crustacean_shellfish, type_of).
primary_ingredient(prawn, crustacean_shellfish, type_of).
primary_ingredient(crayfish, crustacean_shellfish, type_of).

% -Tree nut-
% The Codex always-declare list names six nuts, brazil_nut and macadamia_nut are regional there
primary_ingredient(tree_nuts, tree_nuts, is_allergen).
primary_ingredient(almond, tree_nuts, type_of).
primary_ingredient(walnut, tree_nuts, type_of).
primary_ingredient(cashew, tree_nuts, type_of).
primary_ingredient(pecan, tree_nuts, type_of).
primary_ingredient(pistachio, tree_nuts, type_of).
primary_ingredient(hazelnut, tree_nuts, type_of).
primary_ingredient(brazil_nut, tree_nuts, type_of).
primary_ingredient(macadamia_nut, tree_nuts, type_of).

% -Peanut-
primary_ingredient(peanut, peanut, is_allergen).
primary_ingredient(peanut_flour, peanut, contains).
primary_ingredient(peanut_powder, peanut, contains).

% -Wheat-
primary_ingredient(wheat, wheat, is_allergen).
primary_ingredient(wheat_bran, wheat, part_of).
primary_ingredient(wheat_germ, wheat, part_of).
primary_ingredient(wheat_flour, wheat, contains).
% whole_wheat and wholemeal need a reference check
primary_ingredient(whole_wheat, wheat, contains).
primary_ingredient(wholemeal, wheat, contains).
primary_ingredient(wheat_gluten, wheat, contains).
primary_ingredient(wheat_starch, wheat, contains).

% -Soy-
primary_ingredient(soy, soy, is_allergen).
primary_ingredient(soybean, soy, is_allergen).
primary_ingredient(soy_flour, soy, contains).
primary_ingredient(soy_protein, soy, contains).

% -Sesame-
primary_ingredient(sesame, sesame, is_allergen).
primary_ingredient(sesame_seed, sesame, is_allergen).
primary_ingredient(sesame_flour, sesame, contains).

% -Gluten Containing Cereals-
primary_ingredient(gluten_containing_cereals, gluten_containing_cereals, is_allergen).
primary_ingredient(rye, gluten_containing_cereals, type_of).
primary_ingredient(barley, gluten_containing_cereals, type_of).
primary_ingredient(oats, gluten_containing_cereals, type_of).
primary_ingredient(spelt, gluten_containing_cereals, type_of).

% -Celery-
primary_ingredient(celery, celery, is_allergen).

% -Mustard-
primary_ingredient(mustard, mustard, is_allergen).

% -Sulfites-
primary_ingredient(sulfites, sulfites, is_allergen).

% -Lupin- 
primary_ingredient(lupin, lupin, is_allergen).

% -Molluscs-
primary_ingredient(molluscs, molluscs, is_allergen).
primary_ingredient(scallop, molluscs, type_of).
primary_ingredient(clam, molluscs, type_of).
primary_ingredient(mussel, molluscs, type_of).
primary_ingredient(oyster, molluscs, type_of).


% Derived ingredients are ingredients composed of ingredient/s that contain or are composed of allergen
% Each fact names the immediate source, every chain must end at a primary ingredient
% -Milk-
derived_from(butter, milk).
derived_from(ghee, butter).
derived_from(whey, milk).
derived_from(whey_protein, whey).
derived_from(casein, milk).
derived_from(caseinate, casein).
derived_from(lactose, milk).
derived_from(milk_fat, milk).
% Provisional, Tier 3 support only. Confirm with a Tier 1 or 2 source or remove
derived_from(milk_protein, milk).

% -Egg-
% Provisional, Tier 3 support only. Confirm with a Tier 1 or 2 source or remove
derived_from(egg_lysozyme, egg).

% -Soy-
derived_from(soy_lecithin, soybean).
derived_from(soy_protein_isolate, soybean).
derived_from(tofu, soybean).
derived_from(tempeh, soybean).
derived_from(miso, soybean).

% -Sesame-
derived_from(tahini, sesame_seed).
derived_from(sesame_paste, sesame_seed).

% -Fish-
derived_from(fish_sauce,    fish).
derived_from(fish_gelatin,  fish).

% -Wheat-
derived_from(seitan, wheat_gluten).


% Refined ingredients are processed ingredients that may still come from an allergenic source and are screened as Potential.
refined_from(refined_soybean_oil, soy).
refined_from(refined_peanut_oil, peanut).
refined_from(refined_sesame_oil, sesame).
refined_from(refined_soybean_fat, soy).


% Composite ingredients are standardized products analyzed through their known components
made_with(mayonnaise, egg).
made_with(soy_sauce, soybean).
made_with(soy_sauce, wheat_flour).
made_with(peanut_sauce, peanut).
made_with(egg_noodles, egg).
made_with(marzipan, almond).


% Ambiguous ingredients have an unknown or unspecified allergen source and are reported as Potential.
ambiguous_ingredient(lecithin, [soy, egg]).
ambiguous_ingredient(albumin, [egg, unspecified]).
ambiguous_ingredient(natural_flavor, [unspecified]).
ambiguous_ingredient(flavoring, [unspecified]).
ambiguous_ingredient(vegetable_oil, [unspecified]).
ambiguous_ingredient(hydrolyzed_vegetable_protein, [soy, wheat]).
ambiguous_ingredient(starch, [wheat, unspecified]).
ambiguous_ingredient(flour, [wheat, unspecified]).


% Known ingredients are recognized by the system but have no recorded allergen relationship.
known_ingredient(salt).
known_ingredient(sugar).
known_ingredient(water).
known_ingredient(rice).
known_ingredient(rice_flour).
known_ingredient(corn).
known_ingredient(corn_flour).
known_ingredient(corn_starch).
known_ingredient(potato).
known_ingredient(potato_starch).
known_ingredient(tapioca_starch).
known_ingredient(cassava).
known_ingredient(quinoa).
known_ingredient(xanthan_gum).
known_ingredient(guar_gum).
known_ingredient(citric_acid).
known_ingredient(vinegar).
known_ingredient(olive_oil).
known_ingredient(canola_oil).
known_ingredient(sunflower_oil).
known_ingredient(black_pepper).
known_ingredient(garlic).
known_ingredient(onion).
known_ingredient(yeast).