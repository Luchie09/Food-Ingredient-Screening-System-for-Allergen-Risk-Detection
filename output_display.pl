% Food Ingredient Screening System Output Display
% Printing only, no screening logic
% Gets data from inference_rule.pl and prints it, every screen is one query

% Screens
% screen(+IngredientList), full screening report
% screen(+IngredientList, +UserAllergens), full report with the allergen filter
% screen(+IngredientList, +UserAllergens, +Profiles), same with advice from the allergy profiles
% ingredient_analysis(+Input), one ingredient analyzed
% show_overall_result(+IngredientList), overall result only
% framework_lookup(+Label), frameworks for one label
% screen_for(+UserAllergens, +IngredientList), allergen filter only
% show_ingredients_for_label(+Label), reverse lookup
% show_ingredients_for_label(+Label, +Profile), reverse lookup with advice from the allergy profile
% kb_check, knowledge base size, facts and validation

% Wording rules
% Use identified, potential, not assessed, may wish to avoid and check the label
% Never describe a food as safe or allergen-free except in a negated caution line

:- ensure_loaded(inference_rule).


% Layout Helpers
% Draw the rules, titles, columns and wrapped text at a fixed width
% Used by every screen so the output lines up

% line_width(Width), characters per line
line_width(80).

% rule_double and rule_dash, full-width rules for titles and sections
rule_double :- line_width(Width), format('~`=t~*|~n', [Width]).
rule_dash   :- line_width(Width), format('~`-t~*|~n', [Width]).

% screen_title(+Text)
% Centered title between double rules
screen_title(Text) :-
    line_width(Width),
    atom_length(Text, Length),
    LeftPad is (Width - Length) // 2,
    rule_double,
    format('~*c~w~n', [LeftPad, 32, Text]),
    rule_double.

% section_title(+Text)
% Heading between dashed rules
section_title(Text) :-
    rule_dash,
    format('~w~n', [Text]),
    rule_dash.

% field_line(+Name, +Text)
% A name and its text in two columns
field_line(Name, Text) :-
    format('   ~w~t~25|~w~n', [Name, Text]).

% pad(+Text, +Width, -Padded)
% Right-pad with spaces
pad(Text, Width, Padded) :-
    atom_length(Text, Length),
    PadCount is max(0, Width - Length),
    format(atom(Padded), '~w~*c', [Text, PadCount, 32]).

% print_row(+Cells, +Widths)
% Cells in fixed-width columns with a 3-space indent
% The last cell is printed as is, give it width 0
print_row(Cells, Widths) :-
    maplist(pad, Cells, Widths, PaddedCells),
    atomic_list_concat(PaddedCells, Row),
    format('   ~w~n', [Row]).

% column_width(+Texts, +Padding, -Width)
% Longest text plus padding
column_width(Texts, Padding, Width) :-
    findall(Length, ( member(Text, Texts), atom_length(Text, Length) ), Lengths),
    max_list(Lengths, Longest),
    Width is Longest + Padding.

% print_wrapped(+Indent, +Items)
% Comma-separated items wrapped to the line width
print_wrapped(Indent, Items) :-
    line_width(Max),
    tab(Indent),
    print_item_list(Items, ',', Indent, Indent, Max, first).

% print_paragraph(+Indent, +Text)
% Sentence text wrapped to the line width
print_paragraph(Indent, Text) :-
    line_width(Max),
    atomic_list_concat(Words, ' ', Text),
    tab(Indent),
    print_item_list(Words, '', Indent, Indent, Max, first).

% print_item_list(+Items, +Separator, +Indent, +Column, +Max, +Position)
% Shared worker of print_wrapped and print_paragraph
% A space or line break is written before an item, never after, so lines have no trailing spaces
print_item_list([], _, _, _, _, _) :- nl.
print_item_list([Item|Rest], Separator, Indent, Column, Max, Position) :-
    (   Rest == [] -> UsedSeparator = '' ; UsedSeparator = Separator ),
    atomic_list_concat([Item, UsedSeparator], Text),
    atom_length(Text, Length),
    (   Position == first
    ->  StartColumn = Column
    ;   Column + 1 + Length > Max
    ->  nl, tab(Indent), StartColumn = Indent
    ;   write(' '), StartColumn is Column + 1
    ),
    write(Text),
    EndColumn is StartColumn + Length,
    print_item_list(Rest, Separator, Indent, EndColumn, Max, next).

% print_field_paragraph(+Indent, +Name, +Text)
% "Advice       : text", the text wraps under its own column
print_field_paragraph(Indent, Name, Text) :-
    line_width(Max),
    format(atom(Prefix), '~w~t~14|: ', [Name]),
    atom_length(Prefix, PrefixLength),
    TextIndent is Indent + PrefixLength,
    tab(Indent),
    write(Prefix),
    atomic_list_concat(Words, ' ', Text),
    print_item_list(Words, '', TextIndent, TextIndent, Max, first).


% Wording and Name Formatting
% Turn labels, finding types, paths and results into reader-friendly text
% Used by every screen so the wording stays cautious and consistent

% display_label(+Label, -Text)
% Canonical label to reader-friendly text
display_label(gluten_containing_cereals, 'Gluten-containing cereals') :- !.
display_label(Label, Text) :-
    atomic_list_concat(Parts, '_', Label),
    atomic_list_concat(Parts, ' ', Spaced),
    sub_atom(Spaced, 0, 1, _, First),
    sub_atom(Spaced, 1, _, 0, Rest),
    upcase_atom(First, UpperFirst),
    atom_concat(UpperFirst, Rest, Text).

% display_label_lower(+Label, -Text)
% Same in lowercase, for use inside sentences
display_label_lower(Label, Text) :-
    display_label(Label, Display),
    downcase_atom(Display, Text).

% labels_text(+Labels, -Text)
% "Milk, Wheat" or "None"
labels_text([], 'None') :- !.
labels_text(Labels, Text) :-
    maplist(display_label, Labels, Displays),
    atomic_list_concat(Displays, ', ', Text).

% names_text(+Names, -Text)
% "Milk allergy, Wheat allergy" or "None"
names_text([], 'None') :- !.
names_text(Names, Text) :-
    atomic_list_concat(Names, ', ', Text).

% join_with(+Items, +LastWord, -Text)
% "a", "a and b" or "a, b, and c"
join_with([], _, '').
join_with([Item], _, Item) :- !.
join_with([First, Second], LastWord, Text) :- !,
    atomic_list_concat([First, ' ', LastWord, ' ', Second], Text).
join_with(Items, LastWord, Text) :-
    append(Front, [Last], Items),
    atomic_list_concat(Front, ', ', FrontText),
    atomic_list_concat([FrontText, ', ', LastWord, ' ', Last], Text).

% relationship_phrase(+FindingType, -Phrase)
% How each finding type is worded
relationship_phrase(direct,    'is a source of').
relationship_phrase(contains,  'contains').
relationship_phrase(derived,   'derived from').
relationship_phrase(composite, 'made with').
relationship_phrase(refined,   'refined from').
relationship_phrase(ambiguous, 'may come from').

evidence_text(confirmed, 'Confirmed').
evidence_text(potential, 'Potential').

% path_text(+Path, -Text)
% "ghee -> butter -> milk"
path_text(Path, Text) :-
    atomic_list_concat(Path, ' -> ', Text).

% result_text(+OverallResult, -Text)
% The wording of each overall result
result_text(known_allergen_identified,    'KNOWN ALLERGEN IDENTIFIED').
result_text(potential_allergen_source,    'POTENTIAL ALLERGEN SOURCE').
result_text(insufficient_information,     'INSUFFICIENT INFORMATION').
result_text(no_known_allergen_identified,
            'NO KNOWN ALLERGEN IDENTIFIED IN THE AVAILABLE KNOWLEDGE BASE').

% display_note(+Label, -Note)
% Note for labels whose allergy names are not verified
% These are labeling categories, not diagnoses
display_note(gluten_containing_cereals, 'labeling category only').

% label_risk_text(+Label, -Text)
% The note, else the allergy names, else no allergy name recorded
label_risk_text(Label, Text) :-
    display_note(Label, Note), !,
    Text = Note.
label_risk_text(Label, Text) :-
    allergy_name(Label, Names), !,
    names_text(Names, Text).
label_risk_text(_, 'no allergy name recorded').

% finding_text(+Finding, -Text)
% "ghee: derived from Milk (ghee -> butter -> milk)"
finding_text(f(Ingredient, FindingType, Label, Path), Text) :-
    relationship_phrase(FindingType, Phrase),
    display_label(Label, LabelText),
    (   Path = [_, _|_]
    ->  path_text(Path, PathText),
        format(atom(Text), '~w: ~w ~w (~w)', [Ingredient, Phrase, LabelText, PathText])
    ;   format(atom(Text), '~w: ~w ~w', [Ingredient, Phrase, LabelText])
    ).

% rows_for_findings(+Findings, -Rows)
% Groups findings into table rows in input order
% Ambiguous findings of one ingredient share a row
% Row is row(Ingredient, FindingType, Labels, PathText)
rows_for_findings(Findings, Rows) :-
    findall(Ingredient-FindingType,
            member(f(Ingredient, FindingType, _, _), Findings),
            AllKeys),
    list_to_set(AllKeys, Keys),
    findall(Row,
            (   member(Ingredient-FindingType, Keys),
                key_row(Ingredient, FindingType, Findings, Row)
            ),
            Rows).

key_row(Ingredient, ambiguous, Findings, row(Ingredient, ambiguous, Labels, PathText)) :-
    !,
    findall(Label-Path,
            member(f(Ingredient, ambiguous, Label, Path), Findings),
            Pairs),
    Pairs = [_-FirstPath|_],
    findall(Label, member(Label-_, Pairs), Labels),
    path_text(FirstPath, PathText).
key_row(Ingredient, FindingType, Findings, row(Ingredient, FindingType, [Label], PathText)) :-
    member(f(Ingredient, FindingType, Label, Path), Findings),
    path_text(Path, PathText).

% print_findings_table(+Findings)
% Ingredient, Relationship, Allergen and Path columns
print_findings_table(Findings) :-
    rows_for_findings(Findings, Rows),
    findall(Ingredient, member(row(Ingredient, _, _, _), Rows), Ingredients),
    findall(Text,
            (   member(row(_, _, Labels, _), Rows), labels_text(Labels, Text) ),
            LabelTexts),
    column_width(['Ingredient'|Ingredients], 2, IngredientWidth),
    column_width(['Allergen'|LabelTexts], 2, LabelWidth),
    RelationshipWidth = 16,
    Widths = [IngredientWidth, RelationshipWidth, LabelWidth, 0],
    print_row(['Ingredient', 'Relationship', 'Allergen', 'Path'], Widths),
    forall(member(row(Ingredient, FindingType, Labels, PathText), Rows),
           (   relationship_phrase(FindingType, Phrase),
               labels_text(Labels, LabelText),
               print_row([Ingredient, Phrase, LabelText, PathText], Widths)
           )).


% Full Screening Report
% Prints the report header, Sections 1 to 6 and the disclaimer from diagnosis_report/3
% Used by screen/1, screen/2 and screen/3

% screen(+IngredientList)
% Report without the allergen filter
screen(IngredientList) :-
    screen(IngredientList, []).

% screen(+IngredientList, +UserAllergens)
% Report with the allergen filter lines in Section 6
screen(IngredientList, UserAllergens) :-
    screen(IngredientList, UserAllergens, []).

% screen(+IngredientList, +UserAllergens, +Profiles)
% Same, with the profile and advice under each allergen that has a profile
screen(IngredientList, UserAllergens, Profiles) :-
    diagnosis_report(IngredientList, UserAllergens, Report),
    print_report(Report, Profiles).

% print_report(+Report, +Profiles)
print_report(report(Header, Allergens, Risks, Sources, NotAssessed, Frameworks, Summary),
             Profiles) :-
    nl,
    screen_title('ALLERGEN SCREENING REPORT'),
    print_report_header(Header),
    print_user_allergen_check(Summary, Profiles),
    nl,
    print_allergens_section(Allergens, Sources),
    nl,
    print_risks_section(Risks),
    nl,
    print_sources_section(Sources),
    nl,
    print_not_assessed_section(NotAssessed),
    nl,
    print_frameworks_section(Frameworks),
    nl,
    print_summary_section(Summary, Header, Allergens, NotAssessed),
    print_disclaimer,
    rule_double.

% -Header-
% What was checked, the overall result and the screening counts
print_report_header(report_header(IngredientList, OverallResult,
                                  counts(ConfirmedCount, PotentialCount, NotAssessedCount))) :-
    length(IngredientList, Total),
    format('Ingredients checked (~d):~n', [Total]),
    (   IngredientList == []
    ->  format('  None entered~n')
    ;   print_wrapped(2, IngredientList)
    ),
    nl,
    result_text(OverallResult, ResultText),
    format('Overall result : ~w~n', [ResultText]),
    format('Screening      : ~d Confirmed | ~d Potential | ~d Not assessed~n',
           [ConfirmedCount, PotentialCount, NotAssessedCount]).

% -Your Allergen Check-
% Shown right after the header, only when the user gave allergens
% The result for each of the users allergens comes first because it is what they asked about
print_user_allergen_check(screening_summary(_, []), _) :- !.
print_user_allergen_check(screening_summary(_, FilterResults), Profiles) :-
    nl,
    section_title('YOUR ALLERGEN CHECK'),
    print_filter_lines(FilterResults, Profiles),
    print_profile_limitation(Profiles).

% -Section 1: Allergens Identified-
% Confirmed, Potential and special category labels
% Ambiguous ingredients are named beside the Potential line because their source is unclear
print_allergens_section(allergens_identified(Confirmed, Potential, Special),
                        ingredient_sources(_, PotentialFindings)) :-
    section_title('1. ALLERGENS IDENTIFIED'),
    labels_text(Confirmed, ConfirmedText),
    field_line('Confirmed', ConfirmedText),
    labels_text(Potential, PotentialText),
    findall(Ingredient,
            member(f(Ingredient, ambiguous, _, _), PotentialFindings),
            AmbiguousIngredients0),
    list_to_set(AmbiguousIngredients0, AmbiguousIngredients),
    (   AmbiguousIngredients == [], Potential \== []
    ->  field_line('Potential', PotentialText)
    ;   Potential == []
    ->  field_line('Potential', PotentialText)
    ;   atomic_list_concat(AmbiguousIngredients, ', ', IngredientText),
        format(atom(PotentialLine), '~w  (~w: source unclear)',
               [PotentialText, IngredientText]),
        field_line('Potential', PotentialLine)
    ),
    labels_text(Special, SpecialText),
    field_line('Special categories', SpecialText).

% -Section 2: Associated Allergy Risks-
% Allergy names for the labels
% Special categories are shown separately because they are not diagnoses
print_risks_section(allergy_risks(ConfirmedNames, PotentialNames, SpecialCategoryNames)) :-
    section_title('2. ASSOCIATED ALLERGY RISKS'),
    names_text(ConfirmedNames, ConfirmedText),
    field_line('Confirmed', ConfirmedText),
    names_text(PotentialNames, PotentialText),
    field_line('Potential', PotentialText),
    nl,
    format('   Special categories (labeling categories, not diagnoses)~n'),
    (   SpecialCategoryNames == []
    ->  format('     None~n')
    ;   findall(Label, member(Label-_, SpecialCategoryNames), SpecialLabels),
        findall(Text, ( member(L, SpecialLabels), display_label(L, Text) ), Texts),
        column_width(Texts, 3, Width),
        forall(member(Label, SpecialLabels),
               (   display_label(Label, LabelText),
                   label_risk_text(Label, RiskText),
                   pad(LabelText, Width, PaddedLabel),
                   format('     ~w~w~n', [PaddedLabel, RiskText])
               ))
    ).

% -Section 3: Ingredient Sources-
% Each responsible ingredient with its relationship and path
print_sources_section(ingredient_sources(ConfirmedFindings, PotentialFindings)) :-
    section_title('3. INGREDIENT SOURCES'),
    format('   Confirmed~n'),
    print_source_group(ConfirmedFindings),
    nl,
    format('   Potential~n'),
    print_source_group(PotentialFindings).

print_source_group([]) :- !,
    format('     None~n').
print_source_group(Findings) :-
    print_findings_table(Findings).

% -Section 4: Not Assessed Ingredients-
% Unrecognized, vague and unresolved ingredients with the reason
% They are never treated as allergen-free
print_not_assessed_section(not_assessed(Unrecognized, Vague, Unresolved)) :-
    append([Unrecognized, Vague, Unresolved], All),
    length(All, Total),
    format(atom(Title), '4. NOT ASSESSED INGREDIENTS (~d)', [Total]),
    section_title(Title),
    (   Total =:= 0
    ->  format('   None.~n')
    ;   column_width(All, 4, Width),
        print_not_assessed_group('Not in the knowledge base',
                                 Unrecognized, 'no recorded relationship', Width),
        print_not_assessed_group('Vague terms (source not specified)',
                                 Vague, 'exact source unknown', Width),
        print_not_assessed_group('Relationship chain incomplete',
                                 Unresolved, 'chain never reaches an allergen label', Width),
        format('   Action: check the product label or ask the manufacturer.~n'),
        format('   These ingredients are NOT treated as allergen-free.~n')
    ).

% A group with no ingredient is not printed
print_not_assessed_group(_, [], _, _) :- !.
print_not_assessed_group(Heading, Ingredients, Reason, Width) :-
    format('   ~w~n', [Heading]),
    forall(member(Ingredient, Ingredients),
           (   pad(Ingredient, Width, Padded),
               format('     - ~w~w~n', [Padded, Reason])
           )),
    nl.

% -Section 5: Regulatory Frameworks-
% Which frameworks list each identified label
% A dash means not verified, it does not mean the framework has no rule
print_frameworks_section(regulatory_frameworks(Infos)) :-
    section_title('5. REGULATORY FRAMEWORKS'),
    (   Infos == []
    ->  format('   None. No allergen label was identified.~n')
    ;   print_framework_matrix(Infos),
        nl,
        format('   -  = not verified or not recorded in the source register~n'),
        print_membership_notes(Infos)
    ).

% print_framework_matrix(+Infos)
% One row per label and one column per framework
print_framework_matrix(Infos) :-
    findall(FrameworkId, framework(FrameworkId, _, _), FrameworkIds),
    findall(Text,
            (   member(framework_info(Label, _, _, MemberOf, _), Infos),
                label_cell_text(Label, MemberOf, Text)
            ),
            LabelTexts),
    column_width(['Label'|LabelTexts], 3, LabelWidth),
    findall(Id, ( member(FrameworkId, FrameworkIds), framework_name(FrameworkId, Id) ), HeaderIds),
    framework_widths(FrameworkIds, FrameworkWidths),
    append([LabelWidth], FrameworkWidths, Widths),
    print_row(['Label'|HeaderIds], Widths),
    forall(member(framework_info(Label, Listed, _, MemberOf, _), Infos),
           (   label_cell_text(Label, MemberOf, LabelText),
               findall(Mark,
                       (   member(FrameworkId, FrameworkIds),
                           (   memberchk(FrameworkId, Listed)
                           ->  Mark = listed
                           ;   Mark = '-'
                           )
                       ),
                       Marks),
               print_row([LabelText|Marks], Widths)
           )).

% framework_widths(+Ids, -Widths)
% 8-wide columns, the last one unpadded
framework_widths([_], [0]) :- !.
framework_widths([_|Rest], [8|Widths]) :-
    framework_widths(Rest, Widths).

% label_cell_text(+Label, +MemberOf, -Text)
% Adds * when some frameworks name the label inside a broader category
label_cell_text(Label, [], Text) :- !,
    display_label(Label, Text).
label_cell_text(Label, _, Text) :-
    display_label(Label, Display),
    atom_concat(Display, ' *', Text).

% print_membership_notes(+Infos)
% Explains each * in the matrix
print_membership_notes(Infos) :-
    forall(( member(framework_info(Label, _, _, MemberOf, _), Infos),
             member(Category, MemberOf),
             regulated_by(Category, CategoryFrameworks) ),
           (   maplist(framework_name, CategoryFrameworks, Names),
               join_with(Names, and, NameText),
               display_label(Label, LabelText),
               display_label_lower(Category, CategoryText),
               format('   *  ~w: ~w name it inside ~w~n',
                      [LabelText, NameText, CategoryText])
           )).

framework_name(codex, 'Codex') :- !.
framework_name(FrameworkId, Name) :-
    upcase_atom(FrameworkId, Name).

% -Section 6: Screening Summary-
% The overall result in plain sentences
print_summary_section(screening_summary(OverallResult, _),
                      report_header(IngredientList, _, _),
                      allergens_identified(Confirmed, Potential, _),
                      not_assessed(Unrecognized, Vague, Unresolved)) :-
    section_title('6. SCREENING SUMMARY'),
    result_text(OverallResult, ResultText),
    format('   Result: ~w~n~n', [ResultText]),
    append([Unrecognized, Vague, Unresolved], NotAssessed),
    length(NotAssessed, NotAssessedCount),
    length(IngredientList, Total),
    summary_sentences(OverallResult, Confirmed, Potential, NotAssessedCount, Total, Sentences),
    atomic_list_concat(Sentences, ' ', Paragraph),
    print_paragraph(3, Paragraph),
    nl.

% summary_sentences(+Result, +Confirmed, +Potential, +NotAssessedCount, +Total, -Sentences)
% One clause per overall result
summary_sentences(known_allergen_identified, Confirmed, Potential, NotAssessedCount, _, Sentences) :-
    (   Confirmed == []
    ->  Lead = ['A labeling or sensitivity category was identified (see Section 1).']
    ;   maplist(display_label_lower, Confirmed, Lowered),
        join_with(Lowered, or, LabelText),
        format(atom(S1), 'This list has ingredients linked to ~w.', [LabelText]),
        format(atom(S2), 'People with a ~w allergy may wish to avoid this product.', [LabelText]),
        Lead = [S1, S2]
    ),
    potential_sentence(Potential, PotentialSentences),
    not_assessed_sentence(NotAssessedCount, NotAssessedSentences),
    append([Lead, PotentialSentences, NotAssessedSentences,
            ['Please check the product label.']], Sentences).
summary_sentences(potential_allergen_source, _, Potential, NotAssessedCount, _, Sentences) :-
    potential_sentence(Potential, PotentialSentences),
    not_assessed_sentence(NotAssessedCount, NotAssessedSentences),
    append([['A possible allergen link was found through a refined derivative or an ambiguous term.'],
            PotentialSentences, NotAssessedSentences,
            ['Please check the product label.']], Sentences).
summary_sentences(insufficient_information, _, _, _, 0, Sentences) :- !,
    Sentences = ['No ingredients were entered. No conclusion can be made.'].
summary_sentences(insufficient_information, _, _, NotAssessedCount, _, Sentences) :-
    format(atom(S1), '~d ingredient(s) are unrecognized or vague (see Section 4). No conclusion can be made about them.',
           [NotAssessedCount]),
    Sentences = [S1, 'Please check the product label or the manufacturer.'].
summary_sentences(no_known_allergen_identified, _, _, _, _,
        ['No known allergen identified in the available knowledge base.',
         'This does NOT mean the food is allergen-free or safe.',
         'The system only checks the allergens and ingredients in its knowledge base and cannot detect cross-contact.']).

potential_sentence([], []) :- !.
potential_sentence(Potential, [Sentence]) :-
    maplist(display_label_lower, Potential, Lowered),
    join_with(Lowered, or, LabelText),
    format(atom(Sentence), 'Some ingredients may add a risk for ~w (see Section 3).', [LabelText]).

not_assessed_sentence(0, []) :- !.
not_assessed_sentence(Count, [Sentence]) :-
    format(atom(Sentence), '~d ingredient(s) could not be assessed (see Section 4).', [Count]).

% -Disclaimer-
% Closing caution printed at the end of every report
print_disclaimer :-
    rule_dash,
    print_paragraph(0, 'This is a rule-based screening, not medical advice or a guarantee of food safety. Always check the product label and consult a healthcare professional.').


% Allergen Filter Lines
% Print one cautious line per user allergen
% Shared by the report (Section 6) and the filter screen

% print_filter_lines(+FilterResults)
print_filter_lines(FilterResults) :-
    print_filter_lines(FilterResults, []).

% print_filter_lines(+FilterResults, +Profiles)
% An allergen with a profile also gets its profile and advice lines
print_filter_lines(FilterResults, Profiles) :-
    findall(Text,
            (   member(filter(_, Label, _, _), FilterResults),
                display_label_lower(Label, Text)
            ),
            LabelTexts),
    column_width(LabelTexts, 3, Width),
    forall(member(filter(_, Label, FilterResult, Findings), FilterResults),
           print_filter_line(Label, FilterResult, Findings, Width, Profiles)).

print_filter_line(Label, FilterResult, Findings, Width, Profiles) :-
    display_label_lower(Label, LabelText),
    pad(LabelText, Width, PaddedLabel),
    filter_result_text(FilterResult, LabelText, ResultText),
    format('   ~w~w~n', [PaddedLabel, ResultText]),
    pad('', Width, Blank),
    forall(member(Finding, Findings),
           (   finding_text(Finding, DetailText),
               format('   ~w~w~n', [Blank, DetailText])
           )),
    (   profile_for_label(Label, Profiles, Profile)
    ->  Indent is 3 + Width,
        profile_text(Profile, ProfileText),
        print_field_paragraph(Indent, 'Your profile', ProfileText),
        personal_risk(FilterResult, Profile, Risk),
        risk_advice_text(Risk, Profile, LabelText, AdviceText),
        print_field_paragraph(Indent, 'Advice', AdviceText),
        nl
    ;   true
    ).

% filter_result_text(+FilterResult, +Label, -Text)
% Wording of the four filter results
% None of them says the food is safe
filter_result_text(confirmed_match, Label, Text) :-
    format(atom(Text), 'Not suitable for a ~w allergy', [Label]).
filter_result_text(potential_match, _, 'May not be suitable, check the label').
filter_result_text(no_known_match, Label, Text) :-
    format(atom(Text), 'No known ~w allergen identified in the knowledge base', [Label]).
filter_result_text(unrecognized_allergen, _,
                   'Allergen not recognized, check the spelling').


% Allergy Profile Wording
% The choices the menu offers and the advice printed for each personal risk
% Shared by the report (option 2) and the allergen lookup (option 4)

% tolerance_option(?Tolerance, ?Name, ?Hint)
% The tolerance levels in the order the menu lists them
tolerance_option(severe,   'Severe',   'anaphylaxis, trouble breathing or a hospital visit').
tolerance_option(moderate, 'Moderate', 'hives, swelling or vomiting').
tolerance_option(mild,     'Mild',     'itching, rash or stomach upset').
tolerance_option(not_sure, 'Not sure', 'treated as severe').

% threshold_option(?Threshold, ?Name, ?Hint)
% The trigger thresholds in the order the menu lists them
threshold_option(trace,    'Trace amounts',      'even cross-contact or a "may contain" product').
threshold_option(small,    'Small amounts',      'a bite or a sip').
threshold_option(large,    'Large amounts only', 'a full serving or more').
threshold_option(not_sure, 'Not sure',           'treated as trace amounts').

% profile_text(+Profile, -Text)
% "Severe | Trigger: Trace amounts | Dose: 0.5 mg"
profile_text(profile(_, Tolerance, Threshold, Dose), Text) :-
    tolerance_option(Tolerance, ToleranceName, _),
    threshold_option(Threshold, ThresholdName, _),
    dose_text(Dose, DoseText),
    format(atom(Text), '~w | Trigger: ~w | Dose: ~w',
           [ToleranceName, ThresholdName, DoseText]).

dose_text(none, 'not given') :- !.
dose_text(Dose, Text) :-
    format(atom(Text), '~w mg', [Dose]).

% risk_advice_text(+Risk, +Profile, +LabelText, -Text)
% The advice for one allergen in the report, never a safety claim
risk_advice_text(avoid, Profile, LabelText, Text) :-
    format(atom(Lead), 'AVOID. An ingredient is linked to ~w.', [LabelText]),
    avoid_extra_text(Profile, Extra),
    atomic_list_concat([Lead, Extra], ' ', Text).
risk_advice_text(avoid_unless_confirmed, _, LabelText, Text) :-
    format(atom(Text),
           'AVOID UNLESS CONFIRMED. The ~w link is uncertain and your tolerance leaves little room for it. Eat it only if the label or the manufacturer confirms the source.',
           [LabelText]).
risk_advice_text(check_label, _, LabelText, Text) :-
    format(atom(Text),
           'CHECK THE LABEL. The ~w link is uncertain. Check the label or ask the manufacturer before eating.',
           [LabelText]).
risk_advice_text(cross_contact_caution, _, LabelText, Text) :-
    format(atom(Text),
           'NOT IDENTIFIED, but cross-contact is not checked. With your sensitivity, treat a "may contain ~w" statement as a reason to avoid the product.',
           [LabelText]).
risk_advice_text(no_known_link, _, LabelText, Text) :-
    format(atom(Text),
           'NOT IDENTIFIED. No ~w ingredient was found in the knowledge base. This does NOT mean the product is free of it.',
           [LabelText]).
risk_advice_text(not_assessed, _, _, 'Allergen not recognized, no advice given.').

% avoid_extra_text(+Profile, -Text)
% Severe reactions get an emergency reminder, a lower tolerance gets the reason it still applies
avoid_extra_text(profile(_, severe, _, _), 'Keep any prescribed emergency medicine at hand.') :- !.
avoid_extra_text(Profile, '') :-
    high_sensitivity(Profile), !.
avoid_extra_text(_, 'The amount in the product is not known, so a mild reaction or a high threshold does not make it suitable.').

% profile_limitation_text(-Text)
% What the system cannot do with a profile, shared by the report and the allergen lookup
profile_limitation_text('LIMITATION: The system only detects allergens in the ingredient list. It does not analyze dosage or tolerance level, because its knowledge base holds no ingredient amounts or clinical thresholds. Your profile only sets how cautious the advice is, and your dose is shown for reference only.').

% print_profile_limitation(+Profiles)
% Printed once when the user gave any profile
print_profile_limitation([]) :- !.
print_profile_limitation(_) :-
    profile_limitation_text(Text),
    print_paragraph(3, Text).


% Other Interactive Query Screens
% Each query below runs on its own without the full report
% Used to look at one ingredient, one list, one label or the knowledge base

% -Ingredient Analysis-
% ingredient_analysis(+Input)
% One ingredient in three parts: who it is, how it links to allergens, what that means
ingredient_analysis(Input) :-
    ingredient_explanation(Input,
        explanation(Entered, _, CanonicalName, Category, Findings, Flags)),
    nl,
    screen_title('INGREDIENT ANALYSIS'),
    format('Ingredient entered : ~w~n', [Entered]),
    format('Recognized as      : ~w~n', [CanonicalName]),
    category_text(Category, CategoryText),
    format('Ingredient type    : ~w~n', [CategoryText]),
    analysis_result_text(Findings, Flags, ResultText),
    format('Result             : ~w~n', [ResultText]),
    print_analysis_notes(Findings, Flags),
    (   Findings == []
    ->  true
    ;   nl,
        print_analysis_links(Findings),
        nl,
        print_analysis_meaning(Findings)
    ),
    nl,
    rule_dash,
    format('Rule-based screening. Check the product label.~n'),
    rule_double.

% category_text(+Category, -Text)
category_text(primary,   'Primary ingredient (allergen food or food containing it)').
category_text(derived,   'Derived ingredient (formed from a source)').
category_text(refined,   'Refined ingredient (reported as Potential)').
category_text(composite, 'Composite ingredient (standardized product of components)').
category_text(ambiguous, 'Ambiguous ingredient (source vague or one of several)').
category_text(known,     'Known ingredient (no recorded allergen link)').
category_text(unknown,   'Unknown ingredient (not in the knowledge base)').

% analysis_result_text(+Findings, +Flags, -Text)
% One line that says what the analysis found
analysis_result_text(_, Flags, 'NOT ASSESSED, not in the knowledge base') :-
    memberchk(unrecognized, Flags), !.
analysis_result_text(_, Flags, 'NOT ASSESSED, relationship chain incomplete') :-
    memberchk(unresolved, Flags), !.
analysis_result_text(Findings, _, Text) :-
    Findings \== [], !,
    findall(x, ( member(f(_, Type, _, _), Findings), evidence_level(Type, confirmed) ), C),
    findall(x, ( member(f(_, Type, _, _), Findings), evidence_level(Type, potential) ), P),
    length(C, ConfirmedCount),
    length(P, PotentialCount),
    format(atom(Text), 'Allergen links: ~d Confirmed, ~d Potential',
           [ConfirmedCount, PotentialCount]).
analysis_result_text(_, Flags, 'VAGUE TERM, source not specified') :-
    memberchk(vague, Flags), !.
analysis_result_text(_, _, 'No allergen link recorded').

% print_analysis_notes(+Findings, +Flags)
% A short explanation under the result, never a safety claim
print_analysis_notes(Findings, Flags) :-
    (   memberchk(unrecognized, Flags)
    ->  format('   Not in the knowledge base, so no relationship is recorded.~n'),
        format('   This does NOT mean the ingredient is allergen-free.~n')
    ;   true
    ),
    (   memberchk(unresolved, Flags)
    ->  format('   A relationship is recorded but its chain never reaches an allergen label.~n')
    ;   true
    ),
    (   memberchk(vague, Flags)
    ->  format('   The exact source is not specified. Check the product label.~n')
    ;   true
    ),
    (   Flags == [], Findings == []
    ->  format('   This does NOT mean the ingredient is allergen-free.~n')
    ;   true
    ).

% print_analysis_links(+Findings)
% How the ingredient links to each allergen label
print_analysis_links(Findings) :-
    length(Findings, Count),
    format(atom(Title), 'ALLERGEN LINKS (~d)', [Count]),
    section_title(Title),
    findall(Label, member(f(_, _, Label, _), Findings), Labels0),
    list_to_set(Labels0, Labels),
    findall(Text, ( member(Label, Labels), display_label(Label, Text) ), LabelTexts),
    column_width(['Allergen'|LabelTexts], 2, LabelWidth),
    Widths = [4, 18, LabelWidth, 11, 0],
    print_row(['#', 'How it is linked', 'Allergen', 'Evidence', 'Path'], Widths),
    findall(Index-Finding, nth1(Index, Findings, Finding), Indexed),
    forall(member(Index-f(_, FindingType, Label, Path), Indexed),
           (   relationship_phrase(FindingType, Phrase),
               display_label(Label, LabelText),
               evidence_level(FindingType, EvidenceLevel),
               evidence_text(EvidenceLevel, EvidenceText),
               path_text(Path, PathText),
               atom_number(IndexAtom, Index),
               print_row([IndexAtom, Phrase, LabelText, EvidenceText, PathText], Widths)
           )).

% print_analysis_meaning(+Findings)
% The allergy risk and frameworks of each label found, then a plain sentence
print_analysis_meaning(Findings) :-
    section_title('WHAT IT MEANS'),
    findall(Label, member(f(_, _, Label, _), Findings), Labels0),
    list_to_set(Labels0, Labels),
    findall(Text, ( member(Label, Labels), display_label(Label, Text) ), LabelTexts),
    findall(Text, ( member(Label, Labels), label_risk_text(Label, Text) ), RiskTexts),
    column_width(['Allergen'|LabelTexts], 2, LabelWidth),
    column_width(['Allergy risk'|RiskTexts], 2, RiskWidth),
    Widths = [LabelWidth, RiskWidth, 0],
    print_row(['Allergen', 'Allergy risk', 'Listed by'], Widths),
    forall(member(Label, Labels),
           (   display_label(Label, LabelText),
               label_risk_text(Label, RiskText),
               frameworks_for_label(Label, Frameworks),
               maplist(framework_name, Frameworks, Names),
               atomic_list_concat(Names, ', ', FrameworkText),
               print_row([LabelText, RiskText, FrameworkText], Widths)
           )),
    print_analysis_special_notes(Labels),
    print_analysis_sentences(Findings).

% print_analysis_special_notes(+Labels)
% A label named inside a special category also raises that category
print_analysis_special_notes(Labels) :-
    forall(( member(Label, Labels),
             member_of(Label, Category),
             special_category(Category) ),
           (   display_label(Label, LabelText),
               display_label(Category, CategoryText),
               format(atom(Note),
                      '~w also raises the special category ~w (a labeling category, not a diagnosis).',
                      [LabelText, CategoryText]),
               nl,
               print_paragraph(3, Note)
           )).

% print_analysis_sentences(+Findings)
% Cautious wording only
print_analysis_sentences(Findings) :-
    findall(Label,
            (   member(f(_, Type, Label, _), Findings),
                evidence_level(Type, confirmed),
                \+ special_category(Label) ),
            Confirmed0),
    list_to_set(Confirmed0, Confirmed),
    findall(Label,
            (   member(f(_, Type, Label, _), Findings),
                evidence_level(Type, potential),
                \+ special_category(Label),
                \+ memberchk(Label, Confirmed) ),
            Potential0),
    list_to_set(Potential0, Potential),
    nl,
    (   Confirmed == []
    ->  true
    ;   maplist(display_label_lower, Confirmed, Lowered),
        join_with(Lowered, or, LabelText),
        format(atom(Sentence), 'People with a ~w allergy may wish to avoid this ingredient.', [LabelText]),
        print_paragraph(3, Sentence)
    ),
    (   Potential == []
    ->  true
    ;   maplist(display_label_lower, Potential, PotentialLowered),
        join_with(PotentialLowered, or, PotentialText),
        format(atom(PotentialSentence), 'It may add a risk for ~w. Check the product label.', [PotentialText]),
        print_paragraph(3, PotentialSentence)
    ).

% -Overall Result-
% show_overall_result(+IngredientList)
% Overall result, counts, responsible ingredients and recognized ingredients with no relationship
show_overall_result(IngredientList) :-
    overall_summary(IngredientList,
        summary(OverallResult, counts(ConfirmedCount, PotentialCount, NotAssessedCount),
                Responsible, Recognized)),
    nl,
    screen_title('OVERALL RESULT'),
    length(IngredientList, Total),
    format('Ingredients checked (~d):~n', [Total]),
    (   IngredientList == []
    ->  format('  None entered~n')
    ;   print_wrapped(2, IngredientList)
    ),
    nl,
    result_text(OverallResult, ResultText),
    format('Result    : ~w~n', [ResultText]),
    format('Screening : ~d Confirmed | ~d Potential | ~d Not assessed~n',
           [ConfirmedCount, PotentialCount, NotAssessedCount]),
    overall_extra_line(OverallResult),
    nl,
    rule_dash,
    format('Responsible ingredients~n'),
    (   Responsible == []
    ->  format('   None~n')
    ;   print_findings_table(Responsible)
    ),
    nl,
    format('Recognized, no recorded relationship~n'),
    (   Recognized == []
    ->  format('   None~n')
    ;   atomic_list_concat(Recognized, ', ', RecognizedText),
        format('   ~w~n', [RecognizedText])
    ),
    rule_dash,
    format('Rule-based screening. Check the product label.~n'),
    rule_double.

% overall_extra_line(+OverallResult)
% The extra caution line under the result
overall_extra_line(potential_allergen_source) :- !,
    format('            Check the label.~n').
overall_extra_line(insufficient_information) :- !,
    format('            See the not assessed ingredients.~n').
overall_extra_line(no_known_allergen_identified) :- !,
    format('            This does NOT mean the food is allergen-free or safe.~n'),
    format('            Cross-contact is not checked.~n').
overall_extra_line(_).

% -Framework Lookup-
% framework_lookup(+Label)
% Which frameworks list one label, not verified never means no rule
framework_lookup(LabelInput) :-
    canonical_name(LabelInput, Label),
    nl,
    screen_title('FRAMEWORK LOOKUP'),
    format('Label entered   : ~w~n', [LabelInput]),
    (   framework_info(Label, Listed, _, MemberOf, LabelType)
    ->  display_label(Label, LabelText),
        format('Canonical label : ~w~n', [Label]),
        label_type_text(LabelType, TypeText),
        format('Label type      : ~w~n', [TypeText]),
        nl,
        print_framework_status_table(Listed),
        nl,
        format('   "not verified" means the source register does not list it.~n'),
        format('   It does NOT mean the framework has no rule.~n'),
        print_lookup_membership_notes(LabelText, MemberOf)
    ;   format('Canonical label : ~w~n', [Label]),
        nl,
        format('   Label not recognized. The labels in the knowledge base are:~n'),
        findall(Known, allergen(Known), Knowns),
        print_wrapped(3, Knowns)
    ),
    rule_double.

label_type_text(food_allergy, 'Food allergy').
label_type_text(special_category, 'Special category (labeling or sensitivity)').

print_framework_status_table(Listed) :-
    Widths = [10, 15, 0],
    print_row(['Framework', 'Status', 'Binding'], Widths),
    forall(framework(FrameworkId, _, Binding),
           (   framework_name(FrameworkId, Name),
               (   memberchk(FrameworkId, Listed)
               ->  Status = listed
               ;   Status = 'not verified'
               ),
               binding_text(Binding, BindingText),
               print_row([Name, Status, BindingText], Widths)
           )).

binding_text(mandatory, mandatory).
binding_text(voluntary_adoption, 'voluntary adoption').

print_lookup_membership_notes(_, []) :- !.
print_lookup_membership_notes(LabelText, MemberOf) :-
    forall(( member(Category, MemberOf), regulated_by(Category, CategoryFrameworks) ),
           (   maplist(framework_name, CategoryFrameworks, Names),
               join_with(Names, and, NameText),
               display_label_lower(Category, CategoryText),
               format('   ~w: ~w name it inside ~w.~n', [LabelText, NameText, CategoryText])
           )).

% -Allergen Filter-
% screen_for(+UserAllergens, +IngredientList)
% Checks the list against the users allergens only
screen_for(UserAllergens, IngredientList) :-
    allergen_filter_results(UserAllergens, IngredientList, FilterResults),
    nl,
    screen_title('ALLERGEN FILTER'),
    length(IngredientList, IngredientTotal),
    length(UserAllergens, AllergenTotal),
    format('Ingredients checked (~d):~n', [IngredientTotal]),
    print_wrapped(2, IngredientList),
    format('Allergens to check (~d):~n', [AllergenTotal]),
    print_wrapped(2, UserAllergens),
    nl,
    section_title('RESULTS'),
    print_filter_lines(FilterResults),
    nl,
    rule_dash,
    print_paragraph(0, 'This does NOT mean the food is allergen-free or safe. The system only checks the allergens and ingredients in its knowledge base.'),
    rule_double.

% -Reverse Lookup-
% show_ingredients_for_label(+Label)
% Which ingredients in the knowledge base trigger one allergen
% Header, then Confirmed and Potential tables with how each ingredient is linked
show_ingredients_for_label(LabelInput) :-
    show_ingredients_for_label(LabelInput, none).

% show_ingredients_for_label(+Label, +Profile)
% Same, plus the profile advice when Profile is not none
show_ingredients_for_label(LabelInput, Profile) :-
    canonical_name(LabelInput, Label),
    nl,
    screen_title('INGREDIENTS THAT TRIGGER AN ALLERGEN'),
    (   allergen(Label)
    ->  print_trigger_report(LabelInput, Label, Profile)
    ;   print_unknown_label(LabelInput)
    ),
    rule_double.

% print_trigger_report(+LabelInput, +Label, +Profile)
print_trigger_report(LabelInput, Label, Profile) :-
    label_trigger_rows(Label, Rows),
    display_label(Label, LabelText),
    normalize_name(LabelInput, Normalized),
    (   Normalized == Label
    ->  true
    ;   format('Allergen entered   : ~w~n', [LabelInput])
    ),
    format('Allergen           : ~w~n', [LabelText]),
    label_risk_text(Label, RiskText),
    format('Allergy risk       : ~w~n', [RiskText]),
    frameworks_for_label(Label, Frameworks),
    maplist(framework_name, Frameworks, FrameworkNames),
    atomic_list_concat(FrameworkNames, ', ', FrameworkText),
    format('Listed by          : ~w~n', [FrameworkText]),
    trigger_ingredients(Rows, confirmed, ConfirmedIngredients),
    trigger_ingredients(Rows, potential, PotentialIngredients),
    length(ConfirmedIngredients, ConfirmedCount),
    length(PotentialIngredients, PotentialCount),
    Total is ConfirmedCount + PotentialCount,
    format('Ingredients found  : ~d (~d Confirmed, ~d Potential)~n',
           [Total, ConfirmedCount, PotentialCount]),
    nl,
    print_trigger_group('CONFIRMED', confirmed, Rows, ConfirmedCount,
        'Each has a recorded link to this allergen.'),
    nl,
    print_trigger_group('POTENTIAL', potential, Rows, PotentialCount,
        'The link is uncertain (refined or vague). Check the product label.'),
    print_trigger_via_notes(Label, Rows),
    (   Profile == none
    ->  true
    ;   nl,
        print_lookup_advice(Label, Rows, Profile)
    ),
    nl,
    rule_dash,
    print_paragraph(0, 'Only ingredients in the knowledge base are listed. Absence from this list does NOT mean an ingredient is free of this allergen.').

% trigger_ingredients(+Rows, +Level, -Ingredients)
% The ingredients at one evidence level, each counted once
% An ingredient that is Confirmed is not counted again as Potential
trigger_ingredients(Rows, confirmed, Ingredients) :- !,
    findall(Ingredient, member(trigger(Ingredient, _, _, confirmed, _), Rows), All),
    list_to_set(All, Ingredients).
trigger_ingredients(Rows, potential, Ingredients) :-
    trigger_ingredients(Rows, confirmed, Confirmed),
    findall(Ingredient,
            (   member(trigger(Ingredient, _, _, potential, _), Rows),
                \+ memberchk(Ingredient, Confirmed) ),
            All),
    list_to_set(All, Ingredients).

% print_trigger_group(+Title, +Level, +Rows, +Count, +Intro)
print_trigger_group(Title, Level, Rows, Count, Intro) :-
    format(atom(Heading), '~w (~d)', [Title, Count]),
    section_title(Heading),
    findall(Row, member(Row, Rows), AllRows),
    include(trigger_at_level(Level), AllRows, LevelRows),
    (   LevelRows == []
    ->  format('   None recorded~n')
    ;   print_paragraph(3, Intro),
        nl,
        print_trigger_table(LevelRows)
    ).

trigger_at_level(Level, trigger(_, _, _, Level, _)).

% print_trigger_table(+Rows)
% Ingredient, how it is linked, and the path to the allergen food
print_trigger_table(Rows) :-
    findall(Ingredient, member(trigger(Ingredient, _, _, _, _), Rows), Ingredients),
    findall(Text,
            (   member(trigger(_, Link, _, _, Via), Rows),
                trigger_link_text(Link, Via, Text) ),
            LinkTexts),
    column_width(['Ingredient'|Ingredients], 2, IngredientWidth),
    column_width(['How it is linked'|LinkTexts], 2, LinkWidth),
    Widths = [IngredientWidth, LinkWidth, 0],
    print_row(['Ingredient', 'How it is linked', 'Path'], Widths),
    forall(member(trigger(Ingredient, Link, Path, _, Via), Rows),
           (   trigger_link_text(Link, Via, LinkText),
               trigger_path_text(Path, PathText),
               print_row([Ingredient, LinkText, PathText], Widths)
           )).

% trigger_path_text(+Path, -Text)
% A path of one ingredient adds nothing, so it is shown as a dash
trigger_path_text([_], '-') :- !.
trigger_path_text(Path, Text) :-
    path_text(Path, Text).

% trigger_link_text(+Link, +Via, -Text)
% "(wheat)" is added when the ingredient is linked through a member label
trigger_link_text(Link, none, Text) :- !,
    trigger_phrase(Link, Text).
trigger_link_text(Link, Via, Text) :-
    trigger_phrase(Link, Phrase),
    format(atom(Text), '~w (~w)', [Phrase, Via]).

trigger_phrase(is_allergen, 'is the allergen').
trigger_phrase(type_of,     'type of').
trigger_phrase(part_of,     'part of').
trigger_phrase(contains,    'contains').
trigger_phrase(derived,     'derived from').
trigger_phrase(composite,   'made with').
trigger_phrase(refined,     'refined from').
trigger_phrase(ambiguous,   'may come from').

% print_trigger_via_notes(+Label, +Rows)
% Explains "(wheat)" when some ingredients are listed through a member label
print_trigger_via_notes(Label, Rows) :-
    findall(Via, ( member(trigger(_, _, _, _, Via), Rows), Via \== none ), Vias0),
    list_to_set(Vias0, Vias),
    (   Vias == []
    ->  true
    ;   nl,
        display_label_lower(Label, LabelText),
        forall(member(Via, Vias),
               (   format(atom(Note),
                          '(~w) = linked through ~w, which is named inside ~w',
                          [Via, Via, LabelText]),
                   print_paragraph(3, Note)
               ))
    ).

% print_lookup_advice(+Label, +Rows, +Profile)
% What the profile means for the Confirmed and Potential ingredients and for cross-contact
print_lookup_advice(Label, Rows, Profile) :-
    section_title('YOUR PROFILE ADVICE'),
    profile_text(Profile, ProfileText),
    print_field_paragraph(3, 'Your profile', ProfileText),
    lookup_advice(Profile, lookup_advice(ConfirmedRisk, PotentialRisk, CrossContactRisk)),
    trigger_ingredients(Rows, confirmed, ConfirmedIngredients),
    trigger_ingredients(Rows, potential, PotentialIngredients),
    length(ConfirmedIngredients, ConfirmedCount),
    length(PotentialIngredients, PotentialCount),
    display_label_lower(Label, LabelText),
    lookup_risk_text(ConfirmedRisk, ConfirmedCount, LabelText, ConfirmedText),
    print_field_paragraph(3, 'Confirmed', ConfirmedText),
    lookup_risk_text(PotentialRisk, PotentialCount, LabelText, PotentialText),
    print_field_paragraph(3, 'Potential', PotentialText),
    lookup_risk_text(CrossContactRisk, 0, LabelText, CrossContactText),
    print_field_paragraph(3, 'Cross-contact', CrossContactText),
    (   avoid_extra_text(Profile, Extra), Extra \== ''
    ->  print_field_paragraph(3, 'Note', Extra)
    ;   true
    ),
    nl,
    print_profile_limitation([Profile]).

% lookup_risk_text(+Risk, +Count, +LabelText, -Text)
% The advice line for one group of the allergen lookup
lookup_risk_text(avoid, 0, _, 'None recorded.') :- !.
lookup_risk_text(avoid, Count, _, Text) :-
    format(atom(Text), 'AVOID all ~d ingredient(s) listed as Confirmed.', [Count]).
lookup_risk_text(avoid_unless_confirmed, 0, _, 'None recorded.') :- !.
lookup_risk_text(avoid_unless_confirmed, Count, _, Text) :-
    format(atom(Text),
           'AVOID all ~d unless the label or the manufacturer confirms the source. Your tolerance leaves little room for an uncertain source.',
           [Count]).
lookup_risk_text(check_label, 0, _, 'None recorded.') :- !.
lookup_risk_text(check_label, Count, _, Text) :-
    format(atom(Text),
           'CHECK THE LABEL or ask the manufacturer before eating any of the ~d.',
           [Count]).
lookup_risk_text(cross_contact_caution, _, LabelText, Text) :-
    format(atom(Text),
           'Not checked by the system. With your sensitivity, treat a "may contain ~w" statement as a reason to avoid the product.',
           [LabelText]).
lookup_risk_text(no_known_link, _, LabelText, Text) :-
    format(atom(Text),
           'Not checked by the system. Read any "may contain ~w" statement on the label.',
           [LabelText]).

% print_unknown_label(+LabelInput)
print_unknown_label(LabelInput) :-
    format('Allergen entered   : ~w~n', [LabelInput]),
    nl,
    format('   Allergen not recognized. Use one of these allergens:~n'),
    findall(Known, allergen(Known), Knowns),
    print_wrapped(3, Knowns),
    nl,
    format('   Spaces or underscores both work, for example: tree nuts~n').

% -Knowledge Base Check-
% kb_check
% Prints the knowledge base in 11 numbered sections
% 1 Summary, 2 Allergen labels, 3 Frameworks, 4 Aliases, 5 Primary ingredients,
% 6 Derived, 7 Composite, 8 Refined, 9 Ambiguous, 10 Known, 11 Validation
kb_check :-
    kb_problems(Problems),
    length(Problems, ProblemCount),
    nl,
    screen_title('KNOWLEDGE BASE CHECK'),
    print_kb_summary(ProblemCount),
    nl,
    print_kb_labels,
    nl,
    print_kb_frameworks,
    nl,
    print_kb_aliases,
    nl,
    print_kb_primary,
    nl,
    print_kb_derived,
    nl,
    print_kb_composite,
    nl,
    print_kb_refined,
    nl,
    print_kb_ambiguous,
    nl,
    print_kb_known,
    nl,
    print_kb_validation(Problems),
    rule_double.

% kb_section_title(+Number, +Name, +Count)
% "6. DERIVED INGREDIENTS (20)"
kb_section_title(Number, Name, Count) :-
    format(atom(Title), '~d. ~w (~d)', [Number, Name, Count]),
    section_title(Title).

% print_wrapped_row(+Cells, +Widths, +Items)
% Fixed-width cells, then a comma-separated list that wraps under its own column
print_wrapped_row(Cells, Widths, Items) :-
    line_width(Max),
    maplist(pad, Cells, Widths, PaddedCells),
    atomic_list_concat(PaddedCells, Prefix),
    atom_length(Prefix, PrefixLength),
    Indent is 3 + PrefixLength,
    format('   ~w', [Prefix]),
    (   Items == []
    ->  nl
    ;   print_item_list(Items, ',', Indent, Indent, Max, first)
    ).

% kb_names_text(+Items, -Text)
% "a, b, c" or "none"
kb_names_text([], none) :- !.
kb_names_text(Items, Text) :-
    atomic_list_concat(Items, ', ', Text).

% -Section 1: Summary-
% Validation status and the count of every category
print_kb_summary(ProblemCount) :-
    kb_counts(Counts),
    kb_totals(totals(PrimaryFacts, CompositeProducts, RecognizedTerms)),
    section_title('1. SUMMARY'),
    (   ProblemCount =:= 0
    ->  field_line('Validation', 'OK, no problems found')
    ;   format(atom(Status), '~d problem(s) found, see Section 11', [ProblemCount]),
        field_line('Validation', Status)
    ),
    nl,
    kb_count_line(0, 'Category', 'Count'),
    rule_dash,
    kb_heading_line('Labels and frameworks'),
    kb_count_row(Counts, allergens,           1, 'Allergen labels'),
    kb_count_row(Counts, special_categories,  2, 'of which special categories'),
    kb_count_row(Counts, frameworks,          1, 'Frameworks'),
    kb_count_row(Counts, regulated_by,        1, 'Framework lists (regulated_by)'),
    kb_count_row(Counts, member_of,           1, 'Category memberships (member_of)'),
    kb_count_row(Counts, allergy_names,       1, 'Allergy names'),
    kb_heading_line('Names'),
    kb_count_row(Counts, aliases,             1, 'Aliases'),
    kb_heading_line('Ingredients'),
    kb_count_line(1, 'Primary ingredients', PrimaryFacts),
    kb_count_row(Counts, primary_is_allergen, 2, 'is_allergen'),
    kb_count_row(Counts, primary_type_of,     2, 'type_of'),
    kb_count_row(Counts, primary_part_of,     2, 'part_of'),
    kb_count_row(Counts, primary_contains,    2, 'contains'),
    kb_count_row(Counts, derived,             1, 'Derived ingredients'),
    kb_count_line(1, 'Composite ingredients', CompositeProducts),
    kb_count_row(Counts, composite,           2, 'made_with facts'),
    kb_count_row(Counts, refined,             1, 'Refined ingredients'),
    kb_count_row(Counts, ambiguous,           1, 'Ambiguous ingredients'),
    kb_count_row(Counts, known,               1, 'Known ingredients'),
    rule_dash,
    kb_count_line(0, 'Recognized ingredient terms', RecognizedTerms),
    format('   Each ingredient name is counted once. Labels and aliases are not added again.~n').

% kb_heading_line(+Text)
kb_heading_line(Text) :-
    format('   ~w~n', [Text]).

% kb_count_row(+Counts, +Key, +Level, +Title)
kb_count_row(Counts, Key, Level, Title) :-
    memberchk(Key-Count, Counts),
    kb_count_line(Level, Title, Count).

% kb_count_line(+Level, +Title, +Count)
% Title on the left, count right-aligned, each level is indented 3 more spaces
kb_count_line(Level, Title, Count) :-
    Indent is 3 + Level * 3,
    (   integer(Count)
    ->  format('~*c~w~t~46|~t~d~8+~n', [Indent, 32, Title, Count])
    ;   format('~*c~w~t~46|~t~w~8+~n', [Indent, 32, Title, Count])
    ).

% -Section 2: Allergen Labels-
% Label, type, number of primary ingredients and allergy names
print_kb_labels :-
    kb_label_rows(Rows),
    length(Rows, Count),
    kb_section_title(2, 'ALLERGEN LABELS', Count),
    findall(Label, member(label_row(Label, _, _, _), Rows), Labels),
    column_width(['Label'|Labels], 2, LabelWidth),
    Widths = [LabelWidth, 9, 6, 0],
    print_row(['Label', 'Type', 'Ingr.', 'Allergy name(s)'], Widths),
    forall(member(label_row(Label, LabelType, Names, IngredientCount), Rows),
           (   kb_label_type_text(LabelType, TypeText),
               atom_number(CountText, IngredientCount),
               kb_names_text(Names, NameText),
               print_row([Label, TypeText, CountText, NameText], Widths)
           )),
    nl,
    format('   Ingr.   = primary ingredient facts recorded for the label~n'),
    format('   special = labeling or sensitivity category, not a diagnosis~n').

kb_label_type_text(food_allergy, allergy).
kb_label_type_text(special_category, special).

% -Section 3: Frameworks-
% The four frameworks, then which of them list each label
print_kb_frameworks :-
    findall(Id-Scope-Binding, framework(Id, Scope, Binding), Frameworks),
    length(Frameworks, Count),
    kb_section_title(3, 'FRAMEWORKS', Count),
    print_row(['Id', 'Scope', 'Binding'], [8, 24, 0]),
    forall(member(Id-Scope-Binding, Frameworks),
           print_row([Id, Scope, Binding], [8, 24, 0])),
    nl,
    format('   Coverage by label, regulated_by(Label, Frameworks)~n'),
    findall(Id, member(Id-_-_, Frameworks), Ids),
    findall(Name, ( member(Id, Ids), framework_name(Id, Name) ), HeaderNames),
    findall(Label, regulated_by(Label, _), Labels),
    column_width(['Label'|Labels], 2, LabelWidth),
    kb_matrix_widths(Ids, LabelWidth, Widths),
    print_row(['Label'|HeaderNames], Widths),
    forall(regulated_by(Label, Listed),
           (   findall(Mark,
                       (   member(Id, Ids),
                           (   memberchk(Id, Listed) -> Mark = yes ; Mark = '-' )
                       ),
                       Marks),
               print_row([Label|Marks], Widths)
           )),
    nl,
    format('   -  = not verified or not recorded in the source register~n'),
    forall(member_of(Item, Category),
           format('   ~w is named inside ~w (member_of)~n', [Item, Category])).

% kb_matrix_widths(+Ids, +LabelWidth, -Widths)
% The label column, then 7-wide framework columns, the last one unpadded
kb_matrix_widths(Ids, LabelWidth, [LabelWidth|Rest]) :-
    framework_widths_of(Ids, Rest).

framework_widths_of([_], [0]) :- !.
framework_widths_of([_|Ids], [7|Widths]) :-
    framework_widths_of(Ids, Widths).

% -Section 4: Aliases-
% Alternative names grouped under the canonical name they resolve to
print_kb_aliases :-
    kb_alias_groups(Groups),
    kb_items(aliases, AliasFacts),
    length(AliasFacts, Count),
    kb_section_title(4, 'ALIASES', Count),
    findall(Cell,
            (   member(Canonical-Aliases, Groups),
                length(Aliases, N),
                format(atom(Cell), '~w (~d)', [Canonical, N])
            ),
            Cells),
    column_width(['Canonical name'|Cells], 3, Width),
    print_wrapped_row(['Canonical name'], [Width], ['Aliases']),
    forall(member(Canonical-Aliases, Groups),
           (   length(Aliases, N),
               format(atom(Cell), '~w (~d)', [Canonical, N]),
               print_wrapped_row([Cell], [Width], Aliases)
           )).

% -Section 5: Primary Ingredients-
% Grouped by allergen label, then by relationship
print_kb_primary :-
    kb_totals(totals(PrimaryFacts, _, _)),
    kb_primary_groups(Groups),
    kb_section_title(5, 'PRIMARY INGREDIENTS', PrimaryFacts),
    findall(Cell,
            (   member(Label-RelationshipGroups, Groups),
                kb_primary_group_total(RelationshipGroups, Total),
                format(atom(Cell), '~w (~d)', [Label, Total])
            ),
            Cells),
    column_width(['Label'|Cells], 2, LabelWidth),
    Widths = [LabelWidth, 15],
    print_wrapped_row(['Label', 'Relationship'], Widths, ['Ingredients']),
    forall(member(Label-RelationshipGroups, Groups),
           (   kb_primary_group_total(RelationshipGroups, Total),
               format(atom(Cell), '~w (~d)', [Label, Total]),
               print_primary_group(Cell, LabelWidth, RelationshipGroups)
           )),
    nl,
    format('   is_allergen = the food is the allergen food~n'),
    format('   type_of     = a specific type of the allergen food~n'),
    format('   part_of     = a natural part of the allergen food~n'),
    format('   contains    = a food that carries the allergen as a component~n').

% kb_primary_group_total(+RelationshipGroups, -Total)
kb_primary_group_total(RelationshipGroups, Total) :-
    findall(N, ( member(_-Ingredients, RelationshipGroups), length(Ingredients, N) ), Counts),
    sum_list(Counts, Total).

% print_primary_group(+LabelCell, +LabelWidth, +RelationshipGroups)
% The label is printed on its first row only
print_primary_group(_, _, []) :- !.
print_primary_group(LabelCell, LabelWidth, [Relationship-Ingredients|Rest]) :-
    print_wrapped_row([LabelCell, Relationship], [LabelWidth, 15], Ingredients),
    print_primary_rest('', LabelWidth, Rest).

print_primary_rest(_, _, []).
print_primary_rest(Blank, LabelWidth, [Relationship-Ingredients|Rest]) :-
    print_wrapped_row([Blank, Relationship], [LabelWidth, 15], Ingredients),
    print_primary_rest(Blank, LabelWidth, Rest).

% -Section 6: Derived Ingredients-
% Each product with its full path to an allergen label
print_kb_derived :-
    kb_derived_rows(Rows),
    length(Rows, Count),
    kb_section_title(6, 'DERIVED INGREDIENTS', Count),
    findall(Product, member(row(Product, _, _), Rows), Products),
    findall(Text, ( member(row(_, Path, _), Rows), path_text(Path, Text) ), PathTexts),
    column_width(['Product'|Products], 2, ProductWidth),
    column_width(['Path'|PathTexts], 2, PathWidth),
    Widths = [ProductWidth, PathWidth, 0],
    print_row(['Product', 'Path', 'Allergen label'], Widths),
    forall(member(row(Product, Path, Label), Rows),
           (   path_text(Path, PathText),
               print_row([Product, PathText, Label], Widths)
           )),
    nl,
    format('   Every path ends at a primary ingredient, which gives the label.~n').

% -Section 7: Composite Ingredients-
% Standardized products with their components and the labels they lead to
print_kb_composite :-
    kb_composite_rows(Rows),
    length(Rows, Count),
    kb_section_title(7, 'COMPOSITE INGREDIENTS', Count),
    findall(Product, member(row(Product, _, _), Rows), Products),
    findall(Text, ( member(row(_, Components, _), Rows), kb_names_text(Components, Text) ), ComponentTexts),
    column_width(['Product'|Products], 2, ProductWidth),
    column_width(['Made with'|ComponentTexts], 2, ComponentWidth),
    Widths = [ProductWidth, ComponentWidth, 0],
    print_row(['Product', 'Made with', 'Allergen label(s)'], Widths),
    forall(member(row(Product, Components, Labels), Rows),
           (   kb_names_text(Components, ComponentText),
               kb_names_text(Labels, LabelText),
               print_row([Product, ComponentText, LabelText], Widths)
           )).

% -Section 8: Refined Ingredients-
% Refined derivatives on the researched list, reported as Potential
print_kb_refined :-
    kb_items(refined, Items),
    length(Items, Count),
    kb_section_title(8, 'REFINED INGREDIENTS', Count),
    findall(Product, member(Product-_, Items), Products),
    column_width(['Product'|Products], 2, ProductWidth),
    Widths = [ProductWidth, 17, 0],
    print_row(['Product', 'Allergen label', 'Status'], Widths),
    forall(member(Product-Label, Items),
           print_row([Product, Label, 'Potential'], Widths)).

% -Section 9: Ambiguous Ingredients-
% Vague terms and the sources they may hide
print_kb_ambiguous :-
    kb_items(ambiguous, Items),
    length(Items, Count),
    kb_section_title(9, 'AMBIGUOUS INGREDIENTS', Count),
    findall(Term, member(Term-_, Items), Terms),
    column_width(['Term'|Terms], 2, TermWidth),
    Widths = [TermWidth, 0],
    print_row(['Term', 'Possible sources'], Widths),
    forall(member(Term-Possible, Items),
           (   kb_names_text(Possible, PossibleText),
               print_row([Term, PossibleText], Widths)
           )),
    nl,
    format('   unspecified = source not stated, reported as a vague term~n').

% -Section 10: Known Ingredients-
% Recognized names with no recorded allergen relationship
print_kb_known :-
    kb_items(known, Items),
    length(Items, Count),
    kb_section_title(10, 'KNOWN INGREDIENTS', Count),
    print_wrapped(3, Items),
    nl,
    format('   No recorded relationship is not a safety claim.~n').

% -Section 11: Validation-
% The problems found by kb_problems/1 as a table
print_kb_validation(Problems) :-
    length(Problems, Count),
    kb_section_title(11, 'VALIDATION, PROBLEMS FOUND', Count),
    (   Problems == []
    ->  format('   Every derived and composite chain reaches an allergen label.~n'),
        format('   Every alias, label, framework, and category is consistent.~n')
    ;   findall(row(Name, Item, Detail),
                ( member(Problem, Problems), problem_row(Problem, Name, Item, Detail) ),
                Rows),
        findall(Name, member(row(Name, _, _), Rows), Names),
        findall(Item, member(row(_, Item, _), Rows), Items),
        column_width(['Problem'|Names], 3, NameWidth),
        column_width(['Item'|Items], 3, ItemWidth),
        Widths = [NameWidth, ItemWidth, 0],
        print_row(['Problem', 'Item', 'Detail'], Widths),
        forall(member(row(Name, Item, Detail), Rows),
               print_row([Name, Item, Detail], Widths))
    ).

% problem_row(+Problem, -Name, -Item, -Detail)
% One table row for each kind of problem
problem_row(unresolved_derivation(Derived, Source), unresolved_derivation, Derived, Detail) :-
    format(atom(Detail), 'source: ~w (no path to a label)', [Source]).
problem_row(unresolved_composite(Composite, Component), unresolved_composite, Composite, Detail) :-
    format(atom(Detail), 'component: ~w (no path to a label)', [Component]).
problem_row(unknown_alias_target(Alias, Target), unknown_alias_target, Alias, Detail) :-
    format(atom(Detail), 'target: ~w (not recognized)', [Target]).
problem_row(alias_conflicts_with_ingredient(Alias), alias_conflicts_with_ingredient, Alias,
            'also recorded as an ingredient').
problem_row(multiple_categories(Ingredient, Categories), multiple_categories, Ingredient, Detail) :-
    atomic_list_concat(Categories, ', ', CategoryText),
    format(atom(Detail), 'categories: ~w', [CategoryText]).
problem_row(invalid_label(Predicate, Ingredient, Label), invalid_label, Ingredient, Detail) :-
    format(atom(Detail), '~w uses label ~w', [Predicate, Label]).
problem_row(missing_label_fact(Predicate, Label), missing_label_fact, Label, Predicate).
problem_row(duplicate_label_fact(Predicate, Label), duplicate_label_fact, Label, Predicate).
problem_row(unknown_framework(Label, FrameworkId), unknown_framework, Label, Detail) :-
    format(atom(Detail), 'identifier: ~w', [FrameworkId]).
problem_row(unknown_possible_source(Ingredient, Label), unknown_possible_source, Ingredient, Detail) :-
    format(atom(Detail), 'possible source: ~w', [Label]).
problem_row(invalid_category_membership(Item, Category), invalid_category_membership, Item, Detail) :-
    format(atom(Detail), 'category: ~w', [Category]).