# Food Ingredient Screening System for Allergen Risk Detection

## 1. Project Overview

The Food Ingredient Screening System for Allergen Risk Detection is a rule-based AI prototype developed using Prolog and SWI-Prolog. It identifies potential allergen risks in food ingredients by using a knowledge base and inference rules to trace ingredient relationships. The system generates a screening report showing identified allergens, ingredient derivation paths, and ingredients that cannot be assessed.

## 2. Implementation Procedure

### Step 1: Install SWI-Prolog

Download SWI-Prolog from the [official download page](https://www.swi-prolog.org/download/stable) and install it on your computer.

### Step 2: Download the Project Files

Download and extract the project files into one folder. Ensure that the following four files are in the same folder:

* `menu.pl`
* `output_display.pl`
* `inference_rule.pl`
* `knowledge_base.pl`

### Step 3: Open SWI-Prolog

Launch SWI-Prolog from the Windows Start menu.

### Step 4: Load the System

1. Click **File** in the menu bar.
2. Select **Consult...**.
3. Navigate to the project folder.
4. Select `menu.pl` and click **Open**.

The system will automatically load the other required Prolog files and display the interactive menu.

### Step 5: Run the System

Follow the instructions displayed in the menu to select a screening function and enter the required ingredients. For example, you can enter `wheat flour, sugar, ghee` to screen the ingredients for potential allergen risks.

**Note:** This project is a student prototype for ingredient screening and is not a substitute for professional medical advice or official food-labeling verification.
