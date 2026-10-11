% Food Ingredient Screening System Inference Rules
% Terms used in this file
% Findings are f(CanonicalName, FindingType, Label, Path)
% FindingType is direct, contains, derived, composite, refined or ambiguous
% EvidenceLevel is confirmed or potential
% Path is the chain from the ingredient to the allergen label

:- ensure_loaded(knowledge_base).

:- discontiguous kb_problem/1.


% Input Normalization
% Cleans what the user typed and resolves it to the name used in the knowledge base

% normalize_name(+Input, -NormalizedName)
% Lowercase, trim, spaces become underscores
normalize_name(Input, NormalizedName) :-
    downcase_atom(Input, LowerCase),
    normalize_space(atom(Trimmed), LowerCase),
    atomic_list_concat(Words, ' ', Trimmed),
    atomic_list_concat(Words, '_', NormalizedName).

% canonical_name(+Input, -CanonicalName)
% One alias step only, the name stays the same when there is no alias
canonical_name(Input, CanonicalName) :-
    normalize_name(Input, NormalizedName),
    (   alias(NormalizedName, AliasTarget)
    ->  CanonicalName = AliasTarget
    ;   CanonicalName = NormalizedName
    ).


% Ingredient Derivation Search (DFS)
% Follows derived_from/2 depth-first until a primary ingredient is reached
% Finds which allergen label a derived or composite ingredient leads to allergen used or applied

% derivation_path(+Ingredient, ?Label, -Path)
derivation_path(Ingredient, Label, Path) :-
    trace_derivation(Ingredient, Label, [Ingredient], Path).

% trace_derivation(+Ingredient, ?Label, +VisitedList, -Path)
trace_derivation(Ingredient, Label, _VisitedList, [Ingredient]) :-
    primary_ingredient(Ingredient, Label, _Relationship).
trace_derivation(Ingredient, Label, VisitedList, [Ingredient|RestOfPath]) :-
    derived_from(Ingredient, Source),
    \+ memberchk(Source, VisitedList),
    trace_derivation(Source, Label, [Source|VisitedList], RestOfPath).


% Ingredient Screening
% Looks up what the knowledge base says about one ingredient
% Used by the list screening, the report and the reverse lookup

% canonical_finding(?CanonicalName, ?FindingType, ?Label, ?Path)
% One clause per finding type, CanonicalName can be unbound for the reverse lookup

% -Direct-
% The ingredient is the allergen food, a type of it, or a part of it
canonical_finding(CanonicalName, direct, Label, [CanonicalName]) :-
    primary_ingredient(CanonicalName, Label, Relationship),
    Relationship \== contains.

% -Contains-
% A food that carries the allergen as a component
canonical_finding(CanonicalName, contains, Label, [CanonicalName]) :-
    primary_ingredient(CanonicalName, Label, contains).

% -Derived-
% Formed from a source and followed as a path, ghee to butter to milk
canonical_finding(CanonicalName, derived, Label, [CanonicalName|PathRest]) :-
    derived_from(CanonicalName, Source),
    derivation_path(Source, Label, PathRest).

% -Composite-
% A standardized product made with a component that leads to a label
canonical_finding(CanonicalName, composite, Label, [CanonicalName|PathRest]) :-
    made_with(CanonicalName, Component),
    derivation_path(Component, Label, PathRest).

% -Refined-
% A refined ingredient from the researched list, reported as Potential
canonical_finding(CanonicalName, refined, Label, [CanonicalName]) :-
    refined_from(CanonicalName, Label).

% -Ambiguous-
% A vague term, one finding per possible source, reported as Potential
canonical_finding(CanonicalName, ambiguous, Label, [CanonicalName]) :-
    ambiguous_ingredient(CanonicalName, PossibleSources),
    member(Label, PossibleSources).

% finding(+Input, ?FindingType, ?Label, ?Path)
% The findings for what the user typed
finding(Input, FindingType, Label, Path) :-
    canonical_name(Input, CanonicalName),
    canonical_finding(CanonicalName, FindingType, Label, Path).

% evidence_level(?FindingType, ?EvidenceLevel)
% Refined and ambiguous findings are Potential, the rest are Confirmed
evidence_level(direct,    confirmed).
evidence_level(contains,  confirmed).
evidence_level(derived,   confirmed).
evidence_level(composite, confirmed).
evidence_level(refined,   potential).
evidence_level(ambiguous, potential).

% Recognition checks
% Decide which ingredients are recognized, vague or Not assessed

% is_recognized(+CanonicalName)
% Any knowledge base predicate knows the name
is_recognized(CanonicalName) :- known_ingredient(CanonicalName).
is_recognized(CanonicalName) :- primary_ingredient(CanonicalName, _, _).
is_recognized(CanonicalName) :- derived_from(CanonicalName, _).
is_recognized(CanonicalName) :- made_with(CanonicalName, _).
is_recognized(CanonicalName) :- refined_from(CanonicalName, _).
is_recognized(CanonicalName) :- ambiguous_ingredient(CanonicalName, _).

% is_unrecognized(+Input)
% No knowledge base predicate knows the name
is_unrecognized(Input) :-
    canonical_name(Input, CanonicalName),
    \+ is_recognized(CanonicalName).

% is_unresolved(+Input)
% Derived or composite, but the chain never reaches a label
is_unresolved(Input) :-
    canonical_name(Input, CanonicalName),
    (   derived_from(CanonicalName, _)
    ;   made_with(CanonicalName, _)
    ),
    \+ canonical_finding(CanonicalName, _, _, _).

% is_not_assessed(+Input)
% Unrecognized or unresolved
is_not_assessed(Input) :- is_unrecognized(Input).
is_not_assessed(Input) :- is_unresolved(Input).

% is_vague(+Input)
% An ambiguous term whose source is unspecified
is_vague(Input) :-
    canonical_name(Input, CanonicalName),
    once(canonical_finding(CanonicalName, ambiguous, unspecified, _)).

% canonical_category(+CanonicalName, ?Category)
% The category of an ingredient, used by the ingredient explanation and the validation
canonical_category(CanonicalName, primary) :-
    once(primary_ingredient(CanonicalName, _, _)).
canonical_category(CanonicalName, derived) :-
    once(derived_from(CanonicalName, _)).
canonical_category(CanonicalName, refined) :-
    once(refined_from(CanonicalName, _)).
canonical_category(CanonicalName, composite) :-
    once(made_with(CanonicalName, _)).
canonical_category(CanonicalName, ambiguous) :-
    once(ambiguous_ingredient(CanonicalName, _)).
canonical_category(CanonicalName, known) :-
    known_ingredient(CanonicalName).
canonical_category(CanonicalName, unknown) :-
    \+ is_recognized(CanonicalName).

% ingredient_category(+Input, ?Category)
ingredient_category(Input, Category) :-
    canonical_name(Input, CanonicalName),
    canonical_category(CanonicalName, Category).


% Findings Collection
% Runs the ingredient screening over a whole ingredient list
% Used by the diagnosis, the counts and the allergen filter

% canonical_ingredients(+IngredientList, -CanonicalList)
% Duplicates are removed, order is kept
canonical_ingredients(IngredientList, CanonicalList) :-
    maplist(canonical_name, IngredientList, CanonicalNames),
    list_to_set(CanonicalNames, CanonicalList).

% findings_at_level(+IngredientList, +EvidenceLevel, -Findings)
% Only real allergen labels are kept so unspecified never appears
findings_at_level(IngredientList, EvidenceLevel, Findings) :-
    canonical_ingredients(IngredientList, CanonicalList),
    findall(f(CanonicalName, FindingType, Label, Path),
            (   member(CanonicalName, CanonicalList),
                canonical_finding(CanonicalName, FindingType, Label, Path),
                evidence_level(FindingType, EvidenceLevel),
                allergen(Label)
            ),
            AllFindings),
    list_to_set(AllFindings, Findings).

% allergens_at_level(+IngredientList, +EvidenceLevel, -Labels)
% Food allergy labels only, sorted without duplicates, special categories are left out
allergens_at_level(IngredientList, EvidenceLevel, Labels) :-
    findings_at_level(IngredientList, EvidenceLevel, Findings),
    findall(Label,
            (   member(f(_, _, Label, _), Findings),
                \+ special_category(Label)
            ),
            AllLabels),
    sort(AllLabels, Labels).

% special_categories_at_level(+IngredientList, +EvidenceLevel, -SpecialCategories)
% A wheat finding also raises gluten_containing_cereals through member_of/2
special_categories_at_level(IngredientList, EvidenceLevel, SpecialCategories) :-
    findings_at_level(IngredientList, EvidenceLevel, Findings),
    findall(SpecialCategory,
            (   member(f(_, _, Label, _), Findings),
                label_special_category(Label, SpecialCategory)
            ),
            AllCategories),
    sort(AllCategories, SpecialCategories).

% label_special_category(+Label, ?SpecialCategory)
% A label raises a special category itself or through membership
label_special_category(Label, Label) :-
    special_category(Label).
label_special_category(Label, SpecialCategory) :-
    member_of(Label, SpecialCategory),
    special_category(SpecialCategory).

% Not assessed lists
% Pick out the inputs the system could not fully assess
% Unrecognized is not in the knowledge base, vague has an unspecified source, unresolved never reaches a label
unrecognized_ingredients(IngredientList, Ingredients) :-
    canonical_ingredients(IngredientList, CanonicalList),
    include(is_unrecognized, CanonicalList, Ingredients).

vague_ingredients(IngredientList, Ingredients) :-
    canonical_ingredients(IngredientList, CanonicalList),
    include(is_vague, CanonicalList, Ingredients).

unresolved_ingredients(IngredientList, Ingredients) :-
    canonical_ingredients(IngredientList, CanonicalList),
    include(is_unresolved, CanonicalList, Ingredients).

% not_assessed_ingredients(+IngredientList, -Ingredients)
% All three groups together
not_assessed_ingredients(IngredientList, Ingredients) :-
    unrecognized_ingredients(IngredientList, Unrecognized),
    vague_ingredients(IngredientList, Vague),
    unresolved_ingredients(IngredientList, Unresolved),
    append([Unrecognized, Vague, Unresolved], All),
    list_to_set(All, Ingredients).

% recognized_without_findings(+IngredientList, -Ingredients)
% Recognized, no allergen finding and not vague
recognized_without_findings(IngredientList, Ingredients) :-
    canonical_ingredients(IngredientList, CanonicalList),
    findall(CanonicalName,
            (   member(CanonicalName, CanonicalList),
                is_recognized(CanonicalName),
                \+ has_allergen_finding(CanonicalName),
                \+ is_vague(CanonicalName)
            ),
            Ingredients).

% has_allergen_finding(+CanonicalName)
% Leads to at least one real allergen label
has_allergen_finding(CanonicalName) :-
    once(( canonical_finding(CanonicalName, _, Label, _),
           allergen(Label) )).

% has_finding_at_level(+EvidenceLevel, +CanonicalName)
% Has a finding at this evidence level
has_finding_at_level(EvidenceLevel, CanonicalName) :-
    once(( canonical_finding(CanonicalName, FindingType, Label, _),
           evidence_level(FindingType, EvidenceLevel),
           allergen(Label) )).

% screening_counts(+IngredientList, -Counts)
% Counts of Confirmed, Potential and Not assessed ingredients
% Each ingredient is counted once at its highest evidence level
screening_counts(IngredientList,
                 counts(ConfirmedCount, PotentialCount, NotAssessedCount)) :-
    canonical_ingredients(IngredientList, CanonicalList),
    include(has_finding_at_level(confirmed), CanonicalList, ConfirmedList),
    findall(CanonicalName,
            (   member(CanonicalName, CanonicalList),
                \+ has_finding_at_level(confirmed, CanonicalName),
                has_finding_at_level(potential, CanonicalName)
            ),
            PotentialList),
    not_assessed_ingredients(IngredientList, NotAssessedList),
    length(ConfirmedList, ConfirmedCount),
    length(PotentialList, PotentialCount),
    length(NotAssessedList, NotAssessedCount).


% Diagnosis
% Turns the findings of a list into the overall result and the report data
% Used by output_display.pl to print the screening report

% -Overall Result-
% overall_result(+IngredientList, -OverallResult)
% The first condition that matches wins
% known_allergen_identified, at least one Confirmed finding
% potential_allergen_source, no Confirmed and at least one Potential finding
% insufficient_information, empty list, or no finding and a vague or not assessed item
% no_known_allergen_identified, every ingredient recognized and no finding
% The last result is never a claim that the food is safe
overall_result(IngredientList, OverallResult) :-
    (   IngredientList == []
    ->  OverallResult = insufficient_information
    ;   findings_at_level(IngredientList, confirmed, [_|_])
    ->  OverallResult = known_allergen_identified
    ;   findings_at_level(IngredientList, potential, [_|_])
    ->  OverallResult = potential_allergen_source
    ;   has_incomplete_information(IngredientList)
    ->  OverallResult = insufficient_information
    ;   OverallResult = no_known_allergen_identified
    ).

% has_incomplete_information(+IngredientList)
% A vague or not assessed item blocks a clean result
has_incomplete_information(IngredientList) :-
    once(( member(Input, IngredientList),
           (   is_vague(Input)
           ;   is_not_assessed(Input)
           ) )).

% -Supporting Information-
% Allergy names, special categories and framework facts for the labels found
% Used to fill the report sections

% allergy_names_for_labels(+Labels, -AllergyNames)
% Names that go with these labels
allergy_names_for_labels(Labels, AllergyNames) :-
    findall(AllergyName,
            (   member(Label, Labels),
                allergy_name(Label, Names),
                member(AllergyName, Names)
            ),
            AllNames),
    sort(AllNames, AllergyNames).

% allergy_names_at_level(+IngredientList, +EvidenceLevel, -AllergyNames)
allergy_names_at_level(IngredientList, EvidenceLevel, AllergyNames) :-
    allergens_at_level(IngredientList, EvidenceLevel, Labels),
    allergy_names_for_labels(Labels, AllergyNames).

% special_category_allergy_names(+SpecialCategories, -CategoryNames)
% Returns Label-Names pairs
special_category_allergy_names(SpecialCategories, CategoryNames) :-
    findall(SpecialCategory-Names,
            (   member(SpecialCategory, SpecialCategories),
                allergy_name(SpecialCategory, Names)
            ),
            CategoryNames).

% potential_only_allergens(+IngredientList, -Labels)
% Potential labels that are not already Confirmed
potential_only_allergens(IngredientList, Labels) :-
    allergens_at_level(IngredientList, confirmed, ConfirmedLabels),
    allergens_at_level(IngredientList, potential, PotentialLabels),
    subtract(PotentialLabels, ConfirmedLabels, Labels).

% identified_special_categories(+IngredientList, -SpecialCategories)
% Special categories raised at either evidence level
identified_special_categories(IngredientList, SpecialCategories) :-
    special_categories_at_level(IngredientList, confirmed, ConfirmedCategories),
    special_categories_at_level(IngredientList, potential, PotentialCategories),
    union(ConfirmedCategories, PotentialCategories, Unsorted),
    sort(Unsorted, SpecialCategories).

% frameworks_for_label(+Label, -Frameworks)
frameworks_for_label(Label, Frameworks) :-
    regulated_by(Label, Frameworks).

% unverified_frameworks(+Label, -UnverifiedFrameworks)
% Not listed means not verified, it never means not regulated
unverified_frameworks(Label, UnverifiedFrameworks) :-
    regulated_by(Label, ListedFrameworks),
    findall(FrameworkId,
            (   framework(FrameworkId, _, _),
                \+ memberchk(FrameworkId, ListedFrameworks)
            ),
            UnverifiedFrameworks).

% label_type(+Label, -LabelType)
% food_allergy or special_category
label_type(Label, special_category) :-
    special_category(Label), !.
label_type(_, food_allergy).

% framework_info(+Label, -Listed, -Unverified, -MemberOf, -LabelType)
% The framework picture of one label
framework_info(Label, ListedFrameworks, UnverifiedFrameworks, MemberOf, LabelType) :-
    allergen(Label),
    frameworks_for_label(Label, ListedFrameworks),
    unverified_frameworks(Label, UnverifiedFrameworks),
    findall(Category, member_of(Label, Category), MemberOf),
    label_type(Label, LabelType).

% -Report Sections-
% One predicate per report section
% Each returns a term for output_display.pl to print

% report_header_section(+IngredientList, -Header)
% What was checked, the overall result and the counts
report_header_section(IngredientList,
                      report_header(IngredientList, OverallResult, Counts)) :-
    overall_result(IngredientList, OverallResult),
    screening_counts(IngredientList, Counts).

% allergens_identified_section(+IngredientList, -Section)
% Section 1, the labels found at each level
allergens_identified_section(IngredientList,
        allergens_identified(ConfirmedLabels, PotentialLabels, SpecialCategories)) :-
    allergens_at_level(IngredientList, confirmed, ConfirmedLabels),
    potential_only_allergens(IngredientList, PotentialLabels),
    identified_special_categories(IngredientList, SpecialCategories).

% allergy_risks_section(+IngredientList, -Section)
% Section 2, the allergy names that go with those labels
allergy_risks_section(IngredientList,
        allergy_risks(ConfirmedNames, PotentialNames, SpecialCategoryNames)) :-
    allergens_at_level(IngredientList, confirmed, ConfirmedLabels),
    potential_only_allergens(IngredientList, PotentialLabels),
    identified_special_categories(IngredientList, SpecialCategories),
    allergy_names_for_labels(ConfirmedLabels, ConfirmedNames),
    allergy_names_for_labels(PotentialLabels, PotentialNames),
    special_category_allergy_names(SpecialCategories, SpecialCategoryNames).

% ingredient_sources_section(+IngredientList, -Section)
% Section 3, the ingredient behind each finding and its path
ingredient_sources_section(IngredientList,
        ingredient_sources(ConfirmedFindings, PotentialFindings)) :-
    findings_at_level(IngredientList, confirmed, ConfirmedFindings),
    findings_at_level(IngredientList, potential, PotentialFindings).

% not_assessed_section(+IngredientList, -Section)
% Section 4, the ingredients that could not be assessed
not_assessed_section(IngredientList,
        not_assessed(UnrecognizedIngredients, VagueIngredients, UnresolvedIngredients)) :-
    unrecognized_ingredients(IngredientList, UnrecognizedIngredients),
    vague_ingredients(IngredientList, VagueIngredients),
    unresolved_ingredients(IngredientList, UnresolvedIngredients).

% regulatory_frameworks_section(+IngredientList, -Section)
% Section 5, the frameworks that recognize each identified label
regulatory_frameworks_section(IngredientList,
        regulatory_frameworks(FrameworkInfoList)) :-
    allergens_at_level(IngredientList, confirmed, ConfirmedLabels),
    potential_only_allergens(IngredientList, PotentialLabels),
    identified_special_categories(IngredientList, SpecialCategories),
    append([ConfirmedLabels, PotentialLabels, SpecialCategories], AllLabels),
    findall(framework_info(Label, Listed, Unverified, MemberOf, LabelType),
            (   member(Label, AllLabels),
                framework_info(Label, Listed, Unverified, MemberOf, LabelType)
            ),
            FrameworkInfoList).

% screening_summary_section(+IngredientList, +UserAllergens, -Section)
% Section 6, the overall result and the optional allergen filter results
screening_summary_section(IngredientList, UserAllergens,
        screening_summary(OverallResult, FilterResults)) :-
    overall_result(IngredientList, OverallResult),
    allergen_filter_results(UserAllergens, IngredientList, FilterResults).

% -Diagnosis Report-
% Collects every section into one report term

% diagnosis_report(+IngredientList, -Report)
diagnosis_report(IngredientList, Report) :-
    diagnosis_report(IngredientList, [], Report).

% diagnosis_report(+IngredientList, +UserAllergens, -Report)
% Same, plus the filter results for the user's own allergens
% Report is report(Header, Allergens, Risks, Sources, NotAssessed, Frameworks, Summary)
diagnosis_report(IngredientList, UserAllergens,
        report(Header, Allergens, Risks, Sources, NotAssessed, Frameworks, Summary)) :-
    report_header_section(IngredientList, Header),
    allergens_identified_section(IngredientList, Allergens),
    allergy_risks_section(IngredientList, Risks),
    ingredient_sources_section(IngredientList, Sources),
    not_assessed_section(IngredientList, NotAssessed),
    regulatory_frameworks_section(IngredientList, Frameworks),
    screening_summary_section(IngredientList, UserAllergens, Summary).


% Allergen Filter and Lookup
% Checks a list against the user's own allergens and finds which ingredients lead to a label
% Used by the filter screens and the reverse lookup

% allergen_filter_result(+UserAllergen, +IngredientList, -FilterResult)
% FilterResult is confirmed_match, potential_match, no_known_match or unrecognized_allergen
% no_known_match is not a claim that the food is safe
% A misspelled allergen gives unrecognized_allergen, never no_known_match
allergen_filter_result(UserAllergen, IngredientList, FilterResult) :-
    canonical_name(UserAllergen, Label),
    (   \+ allergen(Label)
    ->  FilterResult = unrecognized_allergen
    ;   findings_at_level(IngredientList, confirmed, ConfirmedFindings),
        memberchk(f(_, _, Label, _), ConfirmedFindings)
    ->  FilterResult = confirmed_match
    ;   findings_at_level(IngredientList, potential, PotentialFindings),
        memberchk(f(_, _, Label, _), PotentialFindings)
    ->  FilterResult = potential_match
    ;   FilterResult = no_known_match
    ).

% matching_findings(+Label, +FilterResult, +IngredientList, -Findings)
% The findings that caused the match
matching_findings(Label, confirmed_match, IngredientList, Findings) :-
    !,
    findings_at_level(IngredientList, confirmed, AllFindings),
    include(finding_has_label(Label), AllFindings, Findings).
matching_findings(Label, potential_match, IngredientList, Findings) :-
    !,
    findings_at_level(IngredientList, potential, AllFindings),
    include(finding_has_label(Label), AllFindings, Findings).
matching_findings(_, _, _, []).

finding_has_label(Label, f(_, _, Label, _)).

% allergen_filter_results(+UserAllergens, +IngredientList, -FilterResults)
% Each result is filter(UserAllergen, CanonicalLabel, FilterResult, Findings)
allergen_filter_results(UserAllergens, IngredientList, FilterResults) :-
    findall(filter(UserAllergen, Label, FilterResult, Findings),
            (   member(UserAllergen, UserAllergens),
                canonical_name(UserAllergen, Label),
                allergen_filter_result(UserAllergen, IngredientList, FilterResult),
                matching_findings(Label, FilterResult, IngredientList, Findings)
            ),
            FilterResults).

% ingredients_for_label(+Label, -Ingredients)
% Reverse lookup, includes the Potential ones (refined and ambiguous)
ingredients_for_label(Label, Ingredients) :-
    (   setof(CanonicalName,
              FindingType^Path^canonical_finding(CanonicalName, FindingType, Label, Path),
              Found)
    ->  Ingredients = Found
    ;   Ingredients = []
    ).

% ingredient_findings_for_label(+Label, -Findings)
% Same lookup, keeping the finding type and path
ingredient_findings_for_label(Label, Findings) :-
    (   setof(f(CanonicalName, FindingType, Label, Path),
              canonical_finding(CanonicalName, FindingType, Label, Path),
              Found)
    ->  Findings = Found
    ;   Findings = []
    ).

% label_trigger_rows(+Label, -Rows)
% Rows for the allergen lookup, trigger(Ingredient, Link, Path, EvidenceLevel, Via)
% Link is is_allergen, type_of, part_of, contains, derived, composite, refined or ambiguous
% Via is none, or the member label when the ingredient is linked through it
% Wheat is named inside gluten_containing_cereals, so wheat ingredients are listed for that label with Via = wheat
label_trigger_rows(Label, Rows) :-
    findall(Source-Via,
            (   Source = Label, Via = none
            ;   member_of(Source, Label), Via = Source
            ),
            Sources),
    findall(trigger(Ingredient, Link, Path, Level, Via),
            (   member(Source-Via, Sources),
                canonical_finding(Ingredient, FindingType, Source, Path),
                trigger_link(FindingType, Ingredient, Source, Link),
                evidence_level(FindingType, Level)
            ),
            AllRows),
    list_to_set(AllRows, Rows).

% trigger_link(+FindingType, +Ingredient, +Label, -Link)
% A direct finding is split into is_allergen, type_of or part_of
trigger_link(direct, Ingredient, Label, Link) :- !,
    primary_ingredient(Ingredient, Label, Link).
trigger_link(FindingType, _, _, FindingType).

% -Explanation and Summary-
% Gathers what is needed to explain one ingredient or summarize one list

% ingredient_flags(+Input, -Flags)
% Any of unrecognized, vague, unresolved
ingredient_flags(Input, Flags) :-
    findall(Flag, ingredient_flag(Input, Flag), Flags).

ingredient_flag(Input, unrecognized) :- is_unrecognized(Input).
ingredient_flag(Input, vague)        :- is_vague(Input).
ingredient_flag(Input, unresolved)   :- is_unresolved(Input).

% ingredient_explanation(+Input, -Explanation)
ingredient_explanation(Input,
        explanation(Input, NormalizedName, CanonicalName, Category, Findings, Flags)) :-
    normalize_name(Input, NormalizedName),
    canonical_name(Input, CanonicalName),
    once(canonical_category(CanonicalName, Category)),
    findall(f(CanonicalName, FindingType, Label, Path),
            (   canonical_finding(CanonicalName, FindingType, Label, Path),
                allergen(Label)
            ),
            Findings),
    ingredient_flags(Input, Flags).

% overall_summary(+IngredientList, -Summary)
overall_summary(IngredientList,
        summary(OverallResult, Counts, Responsible, RecognizedWithoutFindings)) :-
    overall_result(IngredientList, OverallResult),
    screening_counts(IngredientList, Counts),
    findings_at_level(IngredientList, confirmed, ConfirmedFindings),
    findings_at_level(IngredientList, potential, PotentialFindings),
    append(ConfirmedFindings, PotentialFindings, Responsible),
    recognized_without_findings(IngredientList, RecognizedWithoutFindings).


% Knowledge Base Inventory
% Collects the facts of the knowledge base and counts them by category
% Used by kb_check to show what the knowledge base holds, no printing here

% kb_category_key(?Key)
% The categories in the order they are shown
kb_category_key(allergens).
kb_category_key(special_categories).
kb_category_key(frameworks).
kb_category_key(regulated_by).
kb_category_key(member_of).
kb_category_key(allergy_names).
kb_category_key(aliases).
kb_category_key(primary_is_allergen).
kb_category_key(primary_type_of).
kb_category_key(primary_part_of).
kb_category_key(primary_contains).
kb_category_key(derived).
kb_category_key(composite).
kb_category_key(refined).
kb_category_key(ambiguous).
kb_category_key(known).

% kb_items(+Key, -Items)
% Every fact of one category, in file order
kb_items(allergens, Items) :-
    findall(Label, allergen(Label), Items).
kb_items(special_categories, Items) :-
    findall(Label, special_category(Label), Items).
kb_items(frameworks, Items) :-
    findall(framework(Id, Scope, Binding), framework(Id, Scope, Binding), Items).
kb_items(regulated_by, Items) :-
    findall(Label-Frameworks, regulated_by(Label, Frameworks), Items).
kb_items(member_of, Items) :-
    findall(Item-Category, member_of(Item, Category), Items).
kb_items(allergy_names, Items) :-
    findall(Label-Names, allergy_name(Label, Names), Items).
kb_items(aliases, Items) :-
    findall(Alias-Canonical, alias(Alias, Canonical), Items).
kb_items(primary_is_allergen, Items) :-
    findall(Ingredient-Label, primary_ingredient(Ingredient, Label, is_allergen), Items).
kb_items(primary_type_of, Items) :-
    findall(Ingredient-Label, primary_ingredient(Ingredient, Label, type_of), Items).
kb_items(primary_part_of, Items) :-
    findall(Ingredient-Label, primary_ingredient(Ingredient, Label, part_of), Items).
kb_items(primary_contains, Items) :-
    findall(Ingredient-Label, primary_ingredient(Ingredient, Label, contains), Items).
kb_items(derived, Items) :-
    findall(Product-Source, derived_from(Product, Source), Items).
kb_items(composite, Items) :-
    findall(Composite-Component, made_with(Composite, Component), Items).
kb_items(refined, Items) :-
    findall(Refined-Label, refined_from(Refined, Label), Items).
kb_items(ambiguous, Items) :-
    findall(Term-Possible, ambiguous_ingredient(Term, Possible), Items).
kb_items(known, Items) :-
    findall(Ingredient, known_ingredient(Ingredient), Items).

% kb_counts(-Counts)
% Key-Count for every category
kb_counts(Counts) :-
    findall(Key-Count,
            (   kb_category_key(Key),
                kb_items(Key, Items),
                length(Items, Count)
            ),
            Counts).

% kb_totals(-Totals)
% Totals(PrimaryFacts, CompositeProducts, RecognizedTerms)
% RecognizedTerms counts each ingredient name once, labels and aliases are not added again
kb_totals(totals(PrimaryFacts, CompositeProducts, RecognizedTerms)) :-
    aggregate_all(count, primary_ingredient(_, _, _), PrimaryFacts),
    (   setof(Composite, Component^made_with(Composite, Component), Composites)
    ->  length(Composites, CompositeProducts)
    ;   CompositeProducts = 0
    ),
    (   setof(Name, is_recognized(Name), Names)
    ->  length(Names, RecognizedTerms)
    ;   RecognizedTerms = 0
    ).


% kb_label_rows(-Rows)
% One row per allergen label, row(Label, LabelType, AllergyNames, IngredientCount)
% IngredientCount is the number of primary_ingredient/3 facts of the label
kb_label_rows(Rows) :-
    findall(label_row(Label, LabelType, Names, Count),
            (   allergen(Label),
                label_type(Label, LabelType),
                (   allergy_name(Label, Names) -> true ; Names = [] ),
                aggregate_all(count, primary_ingredient(_, Label, _), Count)
            ),
            Rows).

% kb_alias_groups(-Groups)
% Canonical-Aliases, in the order the canonical names first appear
kb_alias_groups(Groups) :-
    findall(Canonical, alias(_, Canonical), AllTargets),
    list_to_set(AllTargets, Targets),
    findall(Canonical-Aliases,
            (   member(Canonical, Targets),
                findall(Alias, alias(Alias, Canonical), Aliases)
            ),
            Groups).

% kb_primary_groups(-Groups)
% Label-RelationshipGroups, each group is Relationship-Ingredients
% Relationships that have no ingredient are left out
kb_primary_groups(Groups) :-
    findall(Label-RelationshipGroups,
            (   allergen(Label),
                findall(Relationship-Ingredients,
                        (   member(Relationship, [is_allergen, type_of, part_of, contains]),
                            findall(Ingredient,
                                    primary_ingredient(Ingredient, Label, Relationship),
                                    Ingredients),
                            Ingredients \== []
                        ),
                        RelationshipGroups)
            ),
            Groups).

% kb_derived_rows(-Rows)
% One row per derived ingredient, row(Product, Path, Label)
% Label is none when the chain never reaches an allergen label
kb_derived_rows(Rows) :-
    findall(row(Product, Path, Label),
            (   derived_from(Product, _),
                kb_derived_row(Product, Path, Label)
            ),
            Rows).

kb_derived_row(Product, Path, Label) :-
    once(canonical_finding(Product, derived, Label, Path)), !.
kb_derived_row(Product, [Product], none).

% kb_composite_rows(-Rows)
% One row per composite product, row(Product, Components, Labels)
kb_composite_rows(Rows) :-
    findall(Product, made_with(Product, _), AllProducts),
    list_to_set(AllProducts, Products),
    findall(row(Product, Components, Labels),
            (   member(Product, Products),
                findall(Component, made_with(Product, Component), Components),
                findall(Label, canonical_finding(Product, composite, Label, _), AllLabels),
                list_to_set(AllLabels, Labels)
            ),
            Rows).


% Knowledge Base Validation
% Finds gaps and conflicts in the knowledge base
% Used by kb_check to review the facts before screening

% kb_problems(-Problems)
% An empty list means no problem was found
kb_problems(Problems) :-
    findall(Problem, kb_problem(Problem), AllProblems),
    sort(AllProblems, Problems).

% kb_problem(-Problem)
% One clause per check

% A derived ingredient whose chain never reaches an allergen label
kb_problem(unresolved_derivation(Derived, Source)) :-
    derived_from(Derived, Source),
    \+ derivation_path(Source, _, _).

% A composite component that never reaches an allergen label
kb_problem(unresolved_composite(Composite, Component)) :-
    made_with(Composite, Component),
    \+ derivation_path(Component, _, _).

% An alias that points to an unknown name
kb_problem(unknown_alias_target(Alias, CanonicalName)) :-
    alias(Alias, CanonicalName),
    \+ is_recognized(CanonicalName).

% An alias that is also an ingredient
kb_problem(alias_conflicts_with_ingredient(Alias)) :-
    alias(Alias, _),
    is_recognized(Alias).

% An ingredient placed in more than one category
kb_problem(multiple_categories(Ingredient, Categories)) :-
    setof(Name, is_recognized(Name), Names),
    member(Ingredient, Names),
    findall(Category, canonical_category(Ingredient, Category), Categories),
    Categories = [_, _|_].

% A fact that uses a label which is not in allergen/1
kb_problem(invalid_label(Predicate, Ingredient, Label)) :-
    (   primary_ingredient(Ingredient, Label, _), Predicate = primary_ingredient
    ;   refined_from(Ingredient, Label),          Predicate = refined_from
    ),
    \+ allergen(Label).

% A label missing a required fact
kb_problem(missing_label_fact(Predicate, Label)) :-
    allergen(Label),
    (   \+ regulated_by(Label, _),          Predicate = regulated_by
    ;   \+ allergy_name(Label, _),          Predicate = allergy_name
    ;   \+ primary_ingredient(Label, Label, _), Predicate = primary_ingredient
    ).

% A label with more than one regulated_by or allergy_name fact
kb_problem(duplicate_label_fact(Predicate, Label)) :-
    allergen(Label),
    (   findall(x, regulated_by(Label, _), [_, _|_]), Predicate = regulated_by
    ;   findall(x, allergy_name(Label, _), [_, _|_]), Predicate = allergy_name
    ).

% A regulated_by list that names an identifier with no framework/3 fact
kb_problem(unknown_framework(Label, FrameworkId)) :-
    regulated_by(Label, Frameworks),
    member(FrameworkId, Frameworks),
    \+ framework(FrameworkId, _, _).

% An ambiguous term that lists something that is neither a label nor unspecified
kb_problem(unknown_possible_source(Ingredient, Label)) :-
    ambiguous_ingredient(Ingredient, PossibleSources),
    member(Label, PossibleSources),
    Label \== unspecified,
    \+ allergen(Label).

% A member_of fact that does not point to a valid label and special category
kb_problem(invalid_category_membership(Item, Category)) :-
    member_of(Item, Category),
    (   \+ allergen(Item)
    ;   \+ special_category(Category)
    ).