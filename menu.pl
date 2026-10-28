% Food Ingredient Screening System Interactive Menu
% Asks the user what to check and calls the screens in output_display.pl
% Reading and printing only, no screening logic
% Loading this file starts the menu, type ?- menu. to start it again

:- ensure_loaded(output_display).

% The menu opens as soon as the file is loaded, exit with 0 to reach the ?- prompt
% tests.pl sets the flag menu_autostart to false so it can run the menu with its own input
:- initialization(start_menu).

start_menu :-
    (   current_prolog_flag(menu_autostart, false)
    ->  true
    ;   menu
    ).


% Menu Options
% The choices shown in the menu, in the order they are printed
% menu_option(Key, Description)
% Key is what the user types, the brackets are added when the menu is printed
menu_option('1', 'Screen ingredients (one or a list)').
menu_option('2', 'Screen ingredients with my allergens').
menu_option('3', 'Analyze one ingredient').
menu_option('4', 'Find ingredients that trigger my allergens').
menu_option('5', 'Check the knowledge base').
menu_option('0', 'Exit').


% Prompt Wording
% Every question is asked the same way: an example line, then "Enter ...: "
% input_kind(Kind, Prompt, Example)
input_kind(ingredients, 'Enter ingredient/s: ', 'wheat flour, sugar, ghee').
input_kind(ingredient,  'Enter ingredient: ',   'ghee').
input_kind(allergens,   'Enter allergen/s (your prescribed allergies): ', 'milk, tree nuts, peanut').


% Menu Loop
% Shows the menu, reads a choice, runs it and comes back until the user exits
% Used by menu/0, the only predicate the user needs to call

% menu
menu :-
    menu_loop.

% menu_loop
% The end of the input also exits the menu
menu_loop :-
    show_menu,
    option_range(Low, High),
    format(atom(Prompt), 'Enter option [~w-~w]: ', [Low, High]),
    read_input(Prompt, Line),
    (   Line == end_of_file
    ->  goodbye
    ;   choice_key(Line, Choice),
        handle_choice(Choice)
    ).

% option_range(-Low, -High)
% The lowest and highest menu keys, used in the prompt and the error message
option_range(Low, High) :-
    findall(Key, menu_option(Key, _), Keys),
    min_member(Low, Keys),
    max_member(High, Keys).

% choice_key(+Line, -Choice)
% The typed choice without spaces or brackets, so 3 and [3] mean the same
choice_key(Line, Choice) :-
    normalize_space(atom(Typed), Line),
    atom_chars(Typed, Chars),
    exclude([Char]>>memberchk(Char, ['[', ']']), Chars, Kept),
    atom_chars(Choice, Kept).

% handle_choice(+Choice)
% 0 exits, a listed number runs that option, anything else asks again
handle_choice('0') :- !,
    goodbye.
handle_choice(Choice) :-
    menu_option(Choice, Text), !,
    option_title(Choice, Text),
    (   run_option(Choice) -> true ; true ),
    wait_for_enter,
    menu_loop.
handle_choice(_) :-
    option_range(Low, High),
    format('~n   Invalid option. Enter a number from ~w to ~w.~n', [Low, High]),
    menu_loop.

show_menu :-
    nl,
    screen_title('ALLERGEN SCREENING MENU'),
    forall(menu_option(Key, Text),
           format('   [~w]   ~w~n', [Key, Text])),
    rule_dash,
    format('   Separate several items with commas, for example: wheat flour, sugar, ghee~n'),
    rule_double.

% option_title(+Key, +Text)
% The chosen option as a heading, so every option starts the same way
option_title(Key, Text) :-
    upcase_atom(Text, Upper),
    format(atom(Title), '[~w] ~w', [Key, Upper]),
    nl,
    section_title(Title).

goodbye :-
    format('~nGoodbye.~n').

wait_for_enter :-
    nl,
    read_input('Press Enter to return to the menu... ', _).


% Menu Actions
% One clause per option, each asks for its input and calls one screen
% An option that gets no input prints a message and returns to the menu

% run_option(+Key)
run_option('1') :-
    ask_list(ingredients, Ingredients),
    run_screen(screen(Ingredients)).
run_option('2') :-
    ask_list(ingredients, Ingredients),
    nl,
    ask_list(allergens, Allergens),
    ask_allergy_profiles(Allergens, _, Profiles),
    run_screen(screen(Ingredients, Allergens, Profiles)).
run_option('3') :-
    ask_one(ingredient, Ingredient),
    run_screen(ingredient_analysis(Ingredient)).
run_option('4') :-
    ask_list(allergens, Allergens),
    ask_allergy_profiles(Allergens, Labels, Profiles),
    forall(member(Label, Labels),
           (   (   profile_for_label(Label, Profiles, Profile) -> true ; Profile = none ),
               run_screen(show_ingredients_for_label(Label, Profile))
           )).
run_option('5') :-
    run_screen(kb_check).

% run_screen(+Goal)
% Runs one screen and keeps the menu alive if the screen fails or raises an error
run_screen(Goal) :-
    catch(   (   call(Goal)
             ->  true
             ;   format('~n   Nothing could be shown for this input.~n')
             ),
             Error,
             print_message(error, Error)).


% Allergy Profile Questions
% Asks the tolerance level, trigger threshold and reaction dose for each allergen
% Used by options 2 and 4, the answers become profile(Label, Tolerance, Threshold, Dose)

% ask_allergy_profiles(+Inputs, -Labels, -Profiles)
% Labels are the recognized allergens, Profiles is empty when the user skips the questions
ask_allergy_profiles(Inputs, Labels, Profiles) :-
    user_allergen_labels(Inputs, Labels, Unrecognized),
    report_unrecognized(Unrecognized),
    (   Labels == []
    ->  Profiles = []
    ;   nl,
        format('   Tolerance details let the advice match how you react to each allergen.~n'),
        ask_yes_no('Add tolerance details? [y/n]: ', Answer),
        (   Answer == yes
        ->  maplist(ask_allergy_profile, Labels, Profiles)
        ;   Profiles = []
        )
    ).

% report_unrecognized(+Inputs)
% Names the typed allergens that are not labels and lists the ones that are
report_unrecognized([]) :- !.
report_unrecognized(Inputs) :-
    atomic_list_concat(Inputs, ', ', Text),
    format('~n   Not recognized: ~w (check the spelling)~n', [Text]),
    format('   Known allergens:~n'),
    findall(Label, allergen(Label), Labels),
    print_wrapped(5, Labels).

% ask_allergy_profile(+Label, -Profile)
ask_allergy_profile(Label, profile(Label, Tolerance, Threshold, Dose)) :-
    display_label(Label, LabelText),
    format(atom(Title), 'ALLERGY PROFILE: ~w', [LabelText]),
    nl,
    section_title(Title),
    ask_option('Tolerance level, how strong your reactions are', tolerance_option, Tolerance),
    ask_option('Trigger threshold, the smallest amount that causes a reaction', threshold_option, Threshold),
    ask_dose(Dose).

% ask_option(+Question, +OptionPredicate, -Value)
% Numbered choices from tolerance_option/3 or threshold_option/3
% The end of the input picks the last choice, which is Not sure
ask_option(Question, OptionPredicate, Value) :-
    findall(Option-Name-Hint, call(OptionPredicate, Option, Name, Hint), Options),
    format('~n   ~w~n', [Question]),
    forall(nth1(Index, Options, _-Name-Hint),
           format('   [~d]   ~w~t~30|(~w)~n', [Index, Name, Hint])),
    length(Options, Count),
    ask_number_choice(Count, Index),
    nth1(Index, Options, Value-_-_).

% ask_number_choice(+Count, -Index)
% Asks again until a number from 1 to Count is typed
ask_number_choice(Count, Index) :-
    format(atom(Prompt), 'Enter choice [1-~d]: ', [Count]),
    read_input(Prompt, Line),
    (   Line == end_of_file
    ->  Index = Count
    ;   choice_key(Line, Key),
        atom_number(Key, Number),
        integer(Number),
        between(1, Count, Number)
    ->  Index = Number
    ;   format('   Please enter a number from 1 to ~d.~n', [Count]),
        ask_number_choice(Count, Index)
    ).

% ask_dose(-Dose)
% Reaction dose in mg of allergen protein, none when skipped
% "0.5", "0.5 mg" and "0.5mg" are all read as 0.5
ask_dose(Dose) :-
    format('~n   Reaction dose in mg of allergen protein (optional, from an allergist or a food challenge)~n'),
    format('   Example: 0.5~n'),
    ask_dose_value(Dose).

ask_dose_value(Dose) :-
    ask_text('Enter dose in mg (or press Enter to skip): ', Text),
    downcase_atom(Text, Lower),
    atomic_list_concat(Parts, mg, Lower),
    atomic_list_concat(Parts, '', NoUnit),
    normalize_space(atom(Value), NoUnit),
    (   Value == ''
    ->  Dose = none
    ;   atom_number(Value, Number),
        Number > 0
    ->  Dose = Number
    ;   format('   Please enter a positive number, for example 0.5, or press Enter to skip.~n'),
        ask_dose_value(Dose)
    ).

% ask_yes_no(+Prompt, -Answer)
% Answer is yes or no, the end of the input counts as no
ask_yes_no(Prompt, Answer) :-
    read_input(Prompt, Line),
    (   Line == end_of_file
    ->  Answer = no
    ;   normalize_space(atom(Typed), Line),
        downcase_atom(Typed, Lower),
        (   memberchk(Lower, [y, yes])
        ->  Answer = yes
        ;   memberchk(Lower, [n, no])
        ->  Answer = no
        ;   format('   Please enter y or n.~n'),
            ask_yes_no(Prompt, Answer)
        )
    ).


% Input Reading
% Reads one line from the user and turns it into atoms
% Typed names are cleaned later by canonical_name/2, so capitals and spaces are fine

% read_input(+Prompt, -Line)
% Line is a string, or end_of_file when the input has ended
% The prompt is given to the system with prompt1/1 and not printed here
% The line editor then knows where the typing starts, so backspace and spaces redraw correctly
read_input(Prompt, Line) :-
    prompt1(Prompt),
    read_line_to_string(user_input, Line).

% ask_text(+Prompt, -Text)
% The typed line with extra spaces removed, empty at the end of the input
ask_text(Prompt, Text) :-
    read_input(Prompt, Line),
    (   Line == end_of_file
    ->  Text = ''
    ;   normalize_space(atom(Text), Line)
    ).

% show_example(+Kind)
% The example line printed above every input prompt
show_example(Kind) :-
    input_kind(Kind, _, Example),
    format('   Example: ~w~n', [Example]).

% ask_one(+Kind, -Atom)
% One value, fails with a message when nothing was typed
ask_one(Kind, Atom) :-
    input_kind(Kind, Prompt, _),
    show_example(Kind),
    ask_text(Prompt, Atom),
    (   Atom == ''
    ->  nothing_entered,
        fail
    ;   true
    ).

% ask_list(+Kind, -Items)
% A comma-separated list, fails with a message when it is empty
ask_list(Kind, Items) :-
    input_kind(Kind, Prompt, _),
    show_example(Kind),
    ask_optional_list(Prompt, Items),
    (   Items == []
    ->  nothing_entered,
        fail
    ;   true
    ).

% ask_optional_list(+Prompt, -Items)
% A comma-separated list that may be empty
ask_optional_list(Prompt, Items) :-
    ask_text(Prompt, Text),
    split_string(Text, ",", " ", Parts),
    exclude(==(""), Parts, NonEmpty),
    maplist(atom_string, Items, NonEmpty).

nothing_entered :-
    format('~n   Nothing entered, returning to the menu.~n').
