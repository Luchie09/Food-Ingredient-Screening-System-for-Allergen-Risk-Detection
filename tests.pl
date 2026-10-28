% Food Ingredient Screening System Test Cases
% Each test case is a menu session: the lines a user types, then the lines the screen must show
% The tests run the real menu with the typed lines as input and check the printed output
% Run all tests with: swipl -g run_tests -t halt tests.pl
% Or load this file and type ?- run_tests.

:- use_module(library(plunit)).

% Stops menu.pl from starting the menu on load, the tests start it themselves
:- create_prolog_flag(menu_autostart, false, [type(boolean)]).
:- ensure_loaded(menu).


% Test Plan
% Typed input is shown as Line1 / Line2 / ..., (Enter) is an empty line
% Every session ends with 0 to exit the menu unless the test says otherwise
% "Outside KB" means the ingredient or allergen is not in the knowledge base
%
% A. OPTION 1, SCREEN INGREDIENTS
% No. Typed input                                  Expected output
% A1  ghee                                         KNOWN ALLERGEN IDENTIFIED, ghee -> butter -> milk
% A2  Wheat Flour, sugar, ghee                     Confirmed: Milk, Wheat, Special categories: Gluten-containing cereals
% A3  refined soybean oil, sugar                   POTENTIAL ALLERGEN SOURCE
% A4  sugar, salt, water                           NO KNOWN ALLERGEN IDENTIFIED IN THE AVAILABLE KNOWLEDGE BASE, This does NOT
% A5  salmon, shrimp, oyster, egg yolk,            10 Confirmed | 2 Potential | 3 Not assessed
%     sesame seed, celery, mustard, lupin,         (one ingredient for each allergen and relationship type)
%     barley, tahini, refined peanut oil,
%     flour, kiwi, rice, chicken
% A6  sulphur dioxide, sugar                       Confirmed: None, Special categories: Sulfites,
%                                                  A labeling or sensitivity category was identified
% A7  seitan                                       Milk not found, Wheat, seitan -> wheat_gluten
% A8  albumin                                      POTENTIAL ALLERGEN SOURCE, 0 Confirmed | 1 Potential | 1 Not assessed
% A9  flavoring, natural flavors                   INSUFFICIENT INFORMATION, Vague terms
% A10 soy sauce, mayonnaise, marzipan              Confirmed: Egg, Soy, Tree nuts, Wheat
% Outside KB
% A11 peanut butter, almond milk, chicken          INSUFFICIENT INFORMATION, 3 Not assessed, never NO KNOWN ALLERGEN
% A12 sugar, xyz unknown                           INSUFFICIENT INFORMATION, - xyz_unknown
% A13 wheet flour (typo)                           INSUFFICIENT INFORMATION, - wheet_flour
% A14 123, @#$                                     2 Not assessed, no error
% Input edge cases
% A15 (Enter)                                      Nothing entered, returning to the menu.
% A16 "   " (spaces only)                          Nothing entered, returning to the menu.
% A17 ,,,                                          Nothing entered, returning to the menu.
% A18 ,,ghee,,                                     Ingredients checked (1)
% A19 GHEE, ghee, Ghee                             Ingredients checked (3), 1 Confirmed | 0 Potential | 0 Not assessed
% A20 wheat_flour                                  Underscores work, Confirmed: Wheat
% A21 Peanuts, groundnut                           Aliases resolve, Confirmed: Peanut
%
% B. OPTION 2, SCREEN WITH MY ALLERGENS
% B1  ghee, refined soybean oil, lecithin /        Not suitable / May not be suitable / Allergen not recognized,
%     dairy, soy, shrimpp / n                      no profile lines
% B2  ghee, sugar / milk, peanut / y /             Severe | Small | 0.5 mg -> AVOID, peanut -> cross-contact warning,
%     1 / 2 / 0.5 mg / 2 / 1 / (Enter)             LIMITATION note
% B3  lecithin / soy / maybe / y /                 Each wrong answer asked again, Mild | Large -> CHECK THE LABEL
%     9 / 3 / [3] / abc / (Enter)
% B4  ghee / milk / y / 3 / 3 / (Enter)            Mild profile and Confirmed is still AVOID
% B5  lecithin / egg / y / 4 / 4 / (Enter)         Not sure is treated as severe, AVOID UNLESS CONFIRMED
% B6  ghee / milk / YES / 2 / 2 /                  YES accepted, 0, -1, 1,5 and abc rejected, 2.5MG read as 2.5 mg
%     0 / -1 / 1,5 / abc / 2.5MG
% B7  ghee / milk, dairy, Cow Milk / y / 1/1/      Aliases merged, one profile and one result line for milk
% B8  sulphur dioxide / sulphites / n              Special category allergen, Not suitable for a sulfites allergy
% B9  rice, sugar / fish / n                       No known fish allergen identified in the knowledge base
% B10 ghee / (Enter)                               Nothing entered, no report
% Outside KB
% B11 ghee / kiwi, latex                           Not recognized: kiwi, latex, no tolerance questions
% B12 wheat flour / gluten / (Enter)               "gluten" is outside KB, Not recognized: gluten
% B13 peanut butter / peanut / n                   No known peanut allergen, but INSUFFICIENT INFORMATION
%                                                  and peanut_butter not assessed
%
% C. OPTION 3, ANALYZE ONE INGREDIENT
% C1  Whey Protein                                 whey_protein -> whey -> milk
% C2  Natural Flavour                              natural_flavor, VAGUE TERM, source not specified
% C3  soy sauce                                    Composite, 2 Confirmed, also raises Gluten-containing cereals
% C4  lecithin                                     Ambiguous, 0 Confirmed, 2 Potential
% C5  albumin                                      1 Potential and The exact source is not specified
% C6  refined peanut oil                           Refined, 0 Confirmed, 1 Potential
% C7  cod                                          Primary ingredient, type of fish
% C8  groundnut                                    Alias, Recognized as: peanut
% C9  rice                                         Known ingredient, No allergen link recorded, not allergen-free
% C10 kiwi (outside KB)                            NOT ASSESSED, not in the knowledge base
% C11 (Enter)                                      Nothing entered, returning to the menu.
%
% D. OPTION 4, FIND INGREDIENTS THAT TRIGGER MY ALLERGENS
% D1  gluten containing cereals / n                contains (wheat), linked through wheat
% D2  soy / y / 1 / 1 / (Enter)                    AVOID all 4 unless confirmed, emergency medicine note
% D3  soy / y / 3 / 3 / (Enter)                    Mild profile, CHECK THE LABEL for the 4 Potential
% D4  milk / y / 2 / 2 / 1.2                       Potential: None recorded, LIMITATION note
% D5  nuts / n                                     Alias, Tree nuts, 10 Confirmed
% D6  Soya, sulphite / n                           Two lookup screens: Soy and Sulfites
% D7  milk, dairy / n                              Aliases merged, one lookup screen
% D8  (Enter)                                      Nothing entered, returning to the menu.
% Outside KB
% D9  shrimpp                                      Not recognized: shrimpp, no lookup screen
% D10 kiwi, latex                                  Not recognized: kiwi, latex, list of known allergens
% D11 kiwi, milk / n                               kiwi reported, Milk screen still shown
%
% E. OPTION 5 AND NAVIGATION
% E1  5                                            KNOWLEDGE BASE CHECK, OK, no problems found
% E2  9 / [1] / sugar                              Invalid option, [1] accepted
% E3  a / 10 / -1 / (Enter) / 1.0                  Five invalid options, each refused
% E4  " 3 " / rice                                 Spaces around the option are ignored
% E5  0                                            Goodbye.
% E6  2 / ghee  (input ends, no 0)                 The menu exits with Goodbye, no loop
% E7  4 / milk / y  (input ends)                   Missing answers default to Not sure, Dose: not given


% Test Helpers

% menu_output(+TypedLines, -Output)
% Runs the menu with TypedLines as the keyboard input and returns everything it printed
% A 0 is added at the end so the menu always exits
menu_output(TypedLines, Output) :-
    append(TypedLines, ['0'], AllLines),
    menu_output_raw(AllLines, Output).

% menu_output_raw(+TypedLines, -Output)
% Same without the 0, used to test what happens when the input ends early
menu_output_raw(TypedLines, Output) :-
    atomic_list_concat(TypedLines, '\n', Joined),
    atom_concat(Joined, '\n', Text),
    stream_property(Keyboard, alias(user_input)),
    setup_call_cleanup(
        (   open_string(Text, Typed),
            set_stream(Typed, alias(user_input))
        ),
        with_output_to(string(Output), menu),
        (   set_stream(Keyboard, alias(user_input)),
            close(Typed)
        )).

% expect_menu(+TypedLines, +Shown, +NotShown)
% Every text in Shown must be printed and no text in NotShown may be printed
expect_menu(TypedLines, Shown, NotShown) :-
    menu_output(TypedLines, Output),
    expect_output(Output, Shown, NotShown).

% expect_output(+Output, +Shown, +NotShown)
expect_output(Output, Shown, NotShown) :-
    forall(member(Text, Shown),
           assertion(sub_string(Output, _, _, _, Text))),
    forall(member(Text, NotShown),
           assertion(\+ sub_string(Output, _, _, _, Text))).

% times_shown(+TypedLines, +Text, -Count)
% How many times Text is printed in the session
times_shown(TypedLines, Text, Count) :-
    menu_output(TypedLines, Output),
    aggregate_all(count, sub_string(Output, _, _, _, Text), Count).


% A. Option 1, Screen Ingredients

:- begin_tests(a_option_1_screen_ingredients).

% A1. A derived ingredient is followed through two steps to its allergen
test(a1_derived_ingredient) :-
    expect_menu(['1', 'ghee', ''],
                ['Overall result : KNOWN ALLERGEN IDENTIFIED',
                 'ghee -> butter -> milk'],
                []).

% A2. Capitals are ignored and wheat also raises gluten-containing cereals
test(a2_list_with_special_category) :-
    expect_menu(['1', 'Wheat Flour, sugar, ghee', ''],
                ['Confirmed             Milk, Wheat',
                 'Special categories    Gluten-containing cereals'],
                []).

% A3. Only a refined ingredient is found, so the result is Potential
test(a3_potential_only) :-
    expect_menu(['1', 'refined soybean oil, sugar', ''],
                ['Overall result : POTENTIAL ALLERGEN SOURCE'],
                []).

% A4. Every ingredient is known and none is linked to an allergen, never called safe
test(a4_no_known_allergen) :-
    expect_menu(['1', 'sugar, salt, water', ''],
                ['NO KNOWN ALLERGEN IDENTIFIED IN THE AVAILABLE KNOWLEDGE BASE',
                 'This does NOT'],
                []).

% A5. One ingredient for each allergen group and relationship type, plus outside KB items
test(a5_every_relationship_type) :-
    expect_menu(['1', 'salmon, shrimp, oyster, egg yolk, sesame seed, celery, mustard, lupin, barley, tahini, refined peanut oil, flour, kiwi, rice, chicken', ''],
                ['Screening      : 10 Confirmed | 2 Potential | 3 Not assessed',
                 'Overall result : KNOWN ALLERGEN IDENTIFIED',
                 'tahini -> sesame_seed',
                 '- kiwi',
                 '- chicken',
                 '- flour'],
                ['- rice']).

% A6. A special category only, the summary does not call it an allergy
test(a6_special_category_only) :-
    expect_menu(['1', 'sulphur dioxide, sugar', ''],
                ['Confirmed             None',
                 'Special categories    Sulfites',
                 'A labeling or sensitivity category was identified'],
                []).

% A7. The chain ends at a primary ingredient that contains wheat
test(a7_derived_through_primary) :-
    expect_menu(['1', 'seitan', ''],
                ['Confirmed             Wheat',
                 'seitan -> wheat_gluten'],
                []).

% A8. A term with an allergen source and an unspecified one is Potential and vague
test(a8_ambiguous_with_unspecified) :-
    expect_menu(['1', 'albumin', ''],
                ['Overall result : POTENTIAL ALLERGEN SOURCE',
                 'Screening      : 0 Confirmed | 1 Potential | 1 Not assessed'],
                []).

% A9. Only vague terms, one found through an alias, give no conclusion
test(a9_only_vague_terms) :-
    expect_menu(['1', 'flavoring, natural flavors', ''],
                ['Overall result : INSUFFICIENT INFORMATION',
                 'Vague terms (source not specified)',
                 '- natural_flavor'],
                []).

% A10. Composite products lead to the labels of their components
test(a10_composite_products) :-
    expect_menu(['1', 'soy sauce, mayonnaise, marzipan', ''],
                ['Confirmed             Egg, Soy, Tree nuts, Wheat',
                 'marzipan -> almond'],
                []).

% A11. Foods outside the KB that sound like allergens are never treated as allergen-free
test(a11_outside_kb_foods) :-
    expect_menu(['1', 'peanut butter, almond milk, chicken', ''],
                ['Overall result : INSUFFICIENT INFORMATION',
                 'Screening      : 0 Confirmed | 0 Potential | 3 Not assessed',
                 '- peanut_butter',
                 '- almond_milk',
                 'These ingredients are NOT treated as allergen-free.'],
                ['NO KNOWN ALLERGEN IDENTIFIED']).

% A12. An unknown ingredient blocks a clean result
test(a12_unknown_ingredient) :-
    expect_menu(['1', 'sugar, xyz unknown', ''],
                ['Overall result : INSUFFICIENT INFORMATION',
                 '- xyz_unknown'],
                ['NO KNOWN ALLERGEN IDENTIFIED']).

% A13. A misspelled ingredient is not assessed, not matched to wheat
test(a13_misspelled_ingredient) :-
    expect_menu(['1', 'wheet flour', ''],
                ['Overall result : INSUFFICIENT INFORMATION',
                 '- wheet_flour'],
                ['Confirmed             Wheat']).

% A14. Numbers and symbols are not assessed and cause no error
test(a14_numbers_and_symbols) :-
    expect_menu(['1', '123, @#$', ''],
                ['Screening      : 0 Confirmed | 0 Potential | 2 Not assessed'],
                ['ERROR', 'Nothing could be shown']).

% A15. Pressing Enter without typing returns to the menu
test(a15_empty_input) :-
    expect_menu(['1', '', ''],
                ['Nothing entered, returning to the menu.'],
                ['ALLERGEN SCREENING REPORT']).

% A16. Spaces only count as nothing entered
test(a16_spaces_only) :-
    expect_menu(['1', '     ', ''],
                ['Nothing entered, returning to the menu.'],
                ['ALLERGEN SCREENING REPORT']).

% A17. Commas only count as nothing entered
test(a17_commas_only) :-
    expect_menu(['1', ',,,', ''],
                ['Nothing entered, returning to the menu.'],
                ['ALLERGEN SCREENING REPORT']).

% A18. Empty items between commas are dropped
test(a18_extra_commas) :-
    expect_menu(['1', ',,ghee,,', ''],
                ['Ingredients checked (1):',
                 'Overall result : KNOWN ALLERGEN IDENTIFIED'],
                []).

% A19. The same ingredient typed three ways is screened once
test(a19_duplicates) :-
    expect_menu(['1', 'GHEE, ghee, Ghee', ''],
                ['Ingredients checked (3):',
                 'Screening      : 1 Confirmed | 0 Potential | 0 Not assessed'],
                []).

% A20. Underscores work the same as spaces
test(a20_underscores) :-
    expect_menu(['1', 'wheat_flour', ''],
                ['Confirmed             Wheat'],
                []).

% A21. Ingredient aliases resolve to the allergen
test(a21_ingredient_aliases) :-
    expect_menu(['1', 'Peanuts, groundnut', ''],
                ['Confirmed             Peanut',
                 'Screening      : 1 Confirmed | 0 Potential | 0 Not assessed'],
                []).

:- end_tests(a_option_1_screen_ingredients).


% B. Option 2, Screen With My Allergens

:- begin_tests(b_option_2_my_allergens).

% B1. An alias, a Potential match and a misspelled allergen, without tolerance details
test(b1_without_profile) :-
    expect_menu(['2', 'ghee, refined soybean oil, lecithin', 'dairy, soy, shrimpp', 'n', ''],
                ['Not suitable for a milk allergy',
                 'May not be suitable, check the label',
                 'Allergen not recognized, check the spelling',
                 'Not recognized: shrimpp'],
                ['Your profile', 'LIMITATION:']).

% B2. Tolerance details change the advice for each allergen
test(b2_with_profile) :-
    expect_menu(['2', 'ghee, sugar', 'milk, peanut', 'y',
                 '1', '2', '0.5 mg',
                 '2', '1', '',
                 ''],
                ['Severe | Trigger: Small amounts | Dose: 0.5 mg',
                 'AVOID. An ingredient is linked to milk.',
                 'Keep any',
                 'Moderate | Trigger: Trace amounts | Dose: not given',
                 'NOT IDENTIFIED, but cross-contact is not checked.',
                 'LIMITATION: The system only detects allergens'],
                []).

% B3. Wrong answers are asked again, [3] is read as 3
test(b3_invalid_profile_answers) :-
    expect_menu(['2', 'lecithin', 'soy', 'maybe', 'y',
                 '9', '3', '[3]', 'abc', '',
                 ''],
                ['Please enter y or n.',
                 'Please enter a number from 1 to 4.',
                 'Please enter a positive number',
                 'Mild | Trigger: Large amounts only | Dose: not given',
                 'CHECK THE LABEL.'],
                []).

% B4. A mild allergy does not soften a Confirmed match
test(b4_mild_confirmed_still_avoid) :-
    expect_menu(['2', 'ghee', 'milk', 'y', '3', '3', '', ''],
                ['Mild | Trigger: Large amounts only',
                 'AVOID. An ingredient is linked to milk.',
                 'a mild reaction or'],
                []).

% B5. Not sure is treated as the most sensitive answer
test(b5_not_sure_is_cautious) :-
    expect_menu(['2', 'lecithin', 'egg', 'y', '4', '4', '', ''],
                ['Not sure | Trigger: Not sure | Dose: not given',
                 'AVOID UNLESS CONFIRMED.'],
                ['CHECK THE LABEL.']).

% B6. YES is accepted and every invalid dose is asked again
test(b6_dose_validation) :-
    menu_output(['2', 'ghee', 'milk', 'YES', '2', '2',
                 '0', '-1', '1,5', 'abc', '2.5MG', ''],
                Output),
    aggregate_all(count, sub_string(Output, _, _, _, 'Please enter a positive number'), Rejected),
    assertion(Rejected == 4),
    expect_output(Output,
                  ['Moderate | Trigger: Small amounts | Dose: 2.5 mg'],
                  ['Please enter y or n.']).

% B7. Aliases of one allergen give one profile and one result line
test(b7_allergen_aliases_merged) :-
    Typed = ['2', 'ghee', 'milk, dairy, Cow Milk', 'y', '1', '1', '', ''],
    times_shown(Typed, 'ALLERGY PROFILE: Milk', Profiles),
    assertion(Profiles == 1),
    times_shown(Typed, 'Not suitable for a milk allergy', Lines),
    assertion(Lines == 1).

% B8. A special category can be checked as an allergen through its alias
test(b8_special_category_allergen) :-
    expect_menu(['2', 'sulphur dioxide', 'sulphites', 'n', ''],
                ['Not suitable for a sulfites allergy'],
                []).

% B9. A recognized allergen with no match is not called safe
test(b9_no_match) :-
    expect_menu(['2', 'rice, sugar', 'fish', 'n', ''],
                ['No known fish allergen identified in the knowledge base',
                 'This does NOT'],
                ['Not suitable']).

% B10. No allergen typed returns to the menu without a report
test(b10_no_allergens) :-
    expect_menu(['2', 'ghee', '', ''],
                ['Nothing entered, returning to the menu.'],
                ['ALLERGEN SCREENING REPORT']).

% B11. Allergens outside the KB are reported and no tolerance question is asked
test(b11_outside_kb_allergens) :-
    expect_menu(['2', 'ghee', 'kiwi, latex', ''],
                ['Not recognized: kiwi, latex',
                 'Known allergens:'],
                ['Tolerance details let the advice', 'ALLERGY PROFILE']).

% B12. "gluten" is not a label, the user is pointed to the known allergens
test(b12_gluten_is_outside_kb) :-
    expect_menu(['2', 'wheat flour', 'gluten', ''],
                ['Not recognized: gluten',
                 'gluten_containing_cereals'],
                []).

% B13. An ingredient outside the KB is not assessed even when the allergen is known
test(b13_outside_kb_ingredient) :-
    expect_menu(['2', 'peanut butter', 'peanut', 'n', ''],
                ['No known peanut allergen identified in the knowledge base',
                 'Overall result : INSUFFICIENT INFORMATION',
                 '- peanut_butter'],
                []).

:- end_tests(b_option_2_my_allergens).


% C. Option 3, Analyze One Ingredient

:- begin_tests(c_option_3_analyze_ingredient).

% C1. Capitals and spaces are cleaned and the full path is shown
test(c1_derived_path) :-
    expect_menu(['3', 'Whey Protein', ''],
                ['Recognized as      : whey_protein',
                 'whey_protein -> whey -> milk'],
                []).

% C2. A spelling alias of a vague term is reported as vague
test(c2_vague_alias) :-
    expect_menu(['3', 'Natural Flavour', ''],
                ['Recognized as      : natural_flavor',
                 'VAGUE TERM, source not specified'],
                []).

% C3. A composite product with two components and a special category
test(c3_composite) :-
    expect_menu(['3', 'soy sauce', ''],
                ['Composite ingredient',
                 'Allergen links: 2 Confirmed, 0 Potential',
                 'also raises the special category'],
                []).

% C4. An ambiguous term with two possible allergens
test(c4_ambiguous) :-
    expect_menu(['3', 'lecithin', ''],
                ['Ambiguous ingredient',
                 'Allergen links: 0 Confirmed, 2 Potential'],
                []).

% C5. An allergen source and an unspecified source at the same time
test(c5_ambiguous_with_unspecified) :-
    expect_menu(['3', 'albumin', ''],
                ['Allergen links: 0 Confirmed, 1 Potential',
                 'The exact source is not specified.'],
                []).

% C6. A refined ingredient is Potential
test(c6_refined) :-
    expect_menu(['3', 'refined peanut oil', ''],
                ['Refined ingredient',
                 'Allergen links: 0 Confirmed, 1 Potential'],
                []).

% C7. A type of an allergen food
test(c7_primary_type_of) :-
    expect_menu(['3', 'cod', ''],
                ['Primary ingredient',
                 'Allergen links: 1 Confirmed, 0 Potential',
                 'Fish allergy'],
                []).

% C8. An ingredient alias
test(c8_ingredient_alias) :-
    expect_menu(['3', 'groundnut', ''],
                ['Ingredient entered : groundnut',
                 'Recognized as      : peanut'],
                []).

% C9. A known ingredient with no allergen link is not called allergen-free
test(c9_known_no_link) :-
    expect_menu(['3', 'rice', ''],
                ['Known ingredient (no recorded allergen link)',
                 'No allergen link recorded',
                 'This does NOT mean the ingredient is allergen-free.'],
                []).

% C10. An ingredient outside the KB is not assessed
test(c10_outside_kb) :-
    expect_menu(['3', 'kiwi', ''],
                ['Unknown ingredient (not in the knowledge base)',
                 'NOT ASSESSED, not in the knowledge base'],
                []).

% C11. Pressing Enter without typing returns to the menu
test(c11_empty_input) :-
    expect_menu(['3', '', ''],
                ['Nothing entered, returning to the menu.'],
                ['INGREDIENT ANALYSIS']).

:- end_tests(c_option_3_analyze_ingredient).


% D. Option 4, Find Ingredients That Trigger My Allergens

:- begin_tests(d_option_4_trigger_lookup).

% D1. A labeling category lists the ingredients of its member label
test(d1_category_through_member) :-
    expect_menu(['4', 'gluten containing cereals', 'n', ''],
                ['contains (wheat)',
                 'linked through wheat'],
                ['YOUR PROFILE ADVICE']).

% D2. A severe profile turns Potential ingredients into avoid unless confirmed
test(d2_severe_profile) :-
    expect_menu(['4', 'soy', 'y', '1', '1', '', ''],
                ['YOUR PROFILE ADVICE',
                 'AVOID all 4 unless the label or the manufacturer confirms',
                 'Keep any prescribed emergency medicine at hand.'],
                []).

% D3. A mild profile asks to check the label for Potential ingredients
test(d3_mild_profile) :-
    expect_menu(['4', 'soy', 'y', '3', '3', '', ''],
                ['Potential     : CHECK THE LABEL or ask the manufacturer',
                 'Read any "may contain soy"'],
                ['AVOID all 4 unless']).

% D4. An allergen with no Potential ingredient, with a dose
test(d4_no_potential_with_dose) :-
    expect_menu(['4', 'milk', 'y', '2', '2', '1.2', ''],
                ['Potential     : None recorded.',
                 'Dose: 1.2 mg',
                 'LIMITATION:'],
                []).

% D5. An allergen alias opens the right label
test(d5_allergen_alias) :-
    expect_menu(['4', 'nuts', 'n', ''],
                ['Allergen           : Tree nuts',
                 'Ingredients found  : 10 (10 Confirmed, 0 Potential)'],
                []).

% D6. Two allergens give two lookup screens, one is a special category
test(d6_two_allergens) :-
    Typed = ['4', 'Soya, sulphite', 'n', ''],
    expect_menu(Typed,
                ['Allergen           : Soy',
                 'Allergen           : Sulfites'],
                []),
    times_shown(Typed, 'INGREDIENTS THAT TRIGGER AN ALLERGEN', Screens),
    assertion(Screens == 2).

% D7. Aliases of one allergen give one lookup screen
test(d7_aliases_merged) :-
    times_shown(['4', 'milk, dairy', 'n', ''], 'INGREDIENTS THAT TRIGGER AN ALLERGEN', Screens),
    assertion(Screens == 1).

% D8. Pressing Enter without typing returns to the menu
test(d8_empty_input) :-
    expect_menu(['4', '', ''],
                ['Nothing entered, returning to the menu.'],
                ['INGREDIENTS THAT TRIGGER AN ALLERGEN']).

% D9. A misspelled allergen gets no lookup screen
test(d9_misspelled_allergen) :-
    expect_menu(['4', 'shrimpp', ''],
                ['Not recognized: shrimpp'],
                ['INGREDIENTS THAT TRIGGER AN ALLERGEN']).

% D10. Allergies outside the KB are reported with the list of known allergens
test(d10_outside_kb_allergens) :-
    expect_menu(['4', 'kiwi, latex', ''],
                ['Not recognized: kiwi, latex',
                 'Known allergens:',
                 'crustacean_shellfish'],
                ['INGREDIENTS THAT TRIGGER AN ALLERGEN']).

% D11. An allergen outside the KB does not stop the known one
test(d11_mixed_known_and_unknown) :-
    Typed = ['4', 'kiwi, milk', 'n', ''],
    expect_menu(Typed,
                ['Not recognized: kiwi',
                 'Allergen           : Milk'],
                []),
    times_shown(Typed, 'INGREDIENTS THAT TRIGGER AN ALLERGEN', Screens),
    assertion(Screens == 1).

:- end_tests(d_option_4_trigger_lookup).


% E. Option 5 and Navigation

:- begin_tests(e_option_5_and_navigation).

% E1. The knowledge base check finds no problem
test(e1_knowledge_base_check) :-
    expect_menu(['5', ''],
                ['KNOWLEDGE BASE CHECK',
                 'OK, no problems found'],
                []).

% E2. A wrong option is refused, a bracketed option is accepted
test(e2_invalid_then_bracketed) :-
    expect_menu(['9', '[1]', 'sugar', ''],
                ['Invalid option. Enter a number from 0 to 5.',
                 '[1] SCREEN INGREDIENTS (ONE OR A LIST)'],
                []).

% E3. Letters, large and negative numbers, an empty line and a decimal are all refused
test(e3_many_invalid_options) :-
    times_shown(['a', '10', '-1', '', '1.0'], 'Invalid option.', Count),
    assertion(Count == 5).

% E4. Spaces around the option are ignored
test(e4_option_with_spaces) :-
    expect_menu([' 3 ', 'rice', ''],
                ['[3] ANALYZE ONE INGREDIENT'],
                ['Invalid option.']).

% E5. 0 exits the menu
test(e5_exit) :-
    expect_menu([],
                ['Goodbye.'],
                ['[1] SCREEN INGREDIENTS']).

% E6. When the input ends in the middle of an option the menu still exits
test(e6_input_ends_early) :-
    menu_output_raw(['2', 'ghee'], Output),
    expect_output(Output,
                  ['Nothing entered, returning to the menu.',
                   'Goodbye.'],
                  []).

% E7. When the input ends during the tolerance questions the answers default to Not sure
test(e7_input_ends_in_profile) :-
    menu_output_raw(['4', 'milk', 'y'], Output),
    expect_output(Output,
                  ['Not sure | Trigger: Not sure | Dose: not given',
                   'Goodbye.'],
                  []).

:- end_tests(e_option_5_and_navigation).
