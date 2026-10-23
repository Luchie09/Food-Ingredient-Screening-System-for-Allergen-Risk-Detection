% Food Ingredient Screening System Interactive Menu
% Asks the user what to check and calls the screens in output_display.pl
% Reading and printing only, no screening logic
% Loading this file starts the menu, type ?- menu. to start it again

:- ensure_loaded(output_display).

% The menu opens as soon as the file is loaded, exit with 0 to reach the ?- prompt
:- initialization(menu).


% Menu Options
% The choices shown in the menu, in the order they are printed
% menu_option(Key, Description)
% Key is what the user types, the brackets are added when the menu is printed
menu_option('1', 'Screen ingredients (one or a list)').
menu_option('2', 'Screen ingredients with my allergens').
menu_option('3', 'Analyze one ingredient').
menu_option('4', 'Find ingredients that trigger an allergen').
menu_option('5', 'Check the knowledge base').
menu_option('0', 'Exit').


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
    read_input('Choose an option: ', Line),
    (   Line == end_of_file
    ->  goodbye
    ;   choice_key(Line, Choice),
        handle_choice(Choice)
    ).

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
    menu_option(Choice, _), !,
    (   run_option(Choice) -> true ; true ),
    wait_for_enter,
    menu_loop.
handle_choice(_) :-
    format('~nPlease enter one of the numbers in the menu.~n'),
    menu_loop.

show_menu :-
    nl,
    screen_title('ALLERGEN SCREENING MENU'),
    forall(menu_option(Key, Text),
           format('   [~w]   ~w~n', [Key, Text])),
    rule_dash,
    format('   Type lists with commas, for example: wheat flour, sugar, ghee~n'),
    rule_double.

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
    ask_list('Ingredient or ingredients (separated by commas): ', Ingredients),
    run_screen(screen(Ingredients)).
run_option('2') :-
    ask_list('Ingredient or ingredients (separated by commas): ', Ingredients),
    ask_list('Your allergens (separated by commas): ', Allergens),
    run_screen(screen(Ingredients, Allergens)).
run_option('3') :-
    ask_one('Ingredient: ', Ingredient),
    run_screen(ingredient_analysis(Ingredient)).
run_option('4') :-
    ask_one('Allergen (for example milk, tree nuts): ', Label),
    run_screen(show_ingredients_for_label(Label)).
run_option('5') :-
    run_screen(kb_check).

% run_screen(+Goal)
% Runs one screen and keeps the menu alive if the screen fails or raises an error
run_screen(Goal) :-
    catch(   (   call(Goal)
             ->  true
             ;   format('~nNothing could be shown for this input.~n')
             ),
             Error,
             print_message(error, Error)).

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

% ask_one(+Prompt, -Atom)
% One value, fails with a message when nothing was typed
ask_one(Prompt, Atom) :-
    ask_text(Prompt, Atom),
    (   Atom == ''
    ->  format('~nNothing entered.~n'),
        fail
    ;   true
    ).

% ask_list(+Prompt, -Items)
% A comma-separated list, fails with a message when it is empty
ask_list(Prompt, Items) :-
    ask_optional_list(Prompt, Items),
    (   Items == []
    ->  format('~nNothing entered.~n'),
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