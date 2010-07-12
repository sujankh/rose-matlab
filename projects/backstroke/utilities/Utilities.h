#pragma once

#include "rose.h"
#include <string>
#include <boost/tuple/tuple.hpp>

namespace backstroke_util
{
	/** Generate a name that is unique in the current scope and any parent and children scopes.
	  * @param baseName the word to be included in the variable names. */
	std::string GenerateUniqueVariableName(SgScopeStatement* scope, std::string baseName = "temp");

	/** Returns true if the given expression refers to a variable. This could include using the
	  * dot and arrow operator to access member variables and the dereferencing / addressof operators.
	  * Note that an expression which is a variable reference necessarily has no side effects. */
	bool IsVariableReference(SgExpression* expression);

	/** Given an expression, generates a temporary variable whose initializer optionally evaluates
	  * that expression. Then, the var reference expression returned can be used instead of the original
	  * expression. The temporary variable created can be reassigned to the expression by the returned SgAssignOp;
	  * this can be used when the expression the variable represents needs to be evaluated. NOTE: This handles
	  * reference types correctly by using pointer types for the temporary.
	  * @param expression Expression which will be replaced by a variable
	  * @param scope scope in which the temporary variable will be generated
	  * @return declaration of the temporary variable, an assignment op to
	  *			reevaluate the expression, and a a variable reference expression to use instead of
	  *         the original expression. Delete the results that you don't need! */
	boost::tuple<SgVariableDeclaration*, SgAssignOp*, SgExpression* > CreateTempVariableForExpression(SgExpression* expression,
		SgScopeStatement* scope, bool initializeInDeclaration);

	/** Return if the value in a SgValueExp object is zero. */
	bool isZero(SgValueExp* value);

	/** Reverse the Sgop_mode from prefix to postfix, or vice versa. */
	SgUnaryOp::Sgop_mode reverseOpMode(SgUnaryOp::Sgop_mode mode);

	/** Check if there is another used variable with the same name in the current scope.
	 * If yes, alter the name until it does not conflict with any other variable name. */
	void validateName(std::string& name, SgNode* root);

	/** Identify if two variables are the same. A variable may be a SgVarRefExp object,
	  * a SgDotExp object, or a SgArrowExp object. */
	bool areSameVariable(SgExpression* exp1, SgExpression* exp2);

	/** If the expression contains the given variable. */
	bool containsVariable(SgExpression* exp, SgExpression* var);

	/** Return whether a basic block contains a break statement. */
	bool hasBreakStmt(SgBasicBlock* body);

	/** If two expressions can be reorderd (in other word, reordering does not change the result). */
	bool canBeReordered(SgExpression* exp1, SgExpression* exp2);

	/** Tell if a type is a STL container type. */
	bool isSTLContainer(SgType* type);

	/** Get the defined copy constructors in a given class. Returns empty vector if the copy constructor is implicit. */
	std::vector<SgMemberFunctionDeclaration*> getCopyConstructors(SgClassDeclaration* class_decl);

	/** Returns a boolean value to indicate whether the return value (rvalue) of the given expression is used. */
	bool isReturnValueUsed(SgExpression* exp);

	/** Prints an error message associated with a certain node. Also outputs the file and location
	  * of the node. */
        void printCompilerError(SgNode* badNode, const char * message);

        /** Returns a vector of nodes of specific type indicated by the template parameter, and the traversal 
         * order can also be passed in. */
        template <class T>
        std::vector<T*> querySubTree(SgNode* root, t_traverseOrder order = postorder)
        {
            struct Traversal : public AstSimpleProcessing
            {
                std::vector<T*> all_nodes;
                virtual void visit(SgNode* n)
                {
                    T* node = dynamic_cast<T*>(n);
                    if (node) all_nodes.push_back(node);
                }
            }; 

            Traversal traversal;
            traversal.traverse(root, order);
            return traversal.all_nodes;
        }

        /** Remove braces of a basic block in which there is no variable declared. */
        void removeUselessBraces(SgNode* root);

        /** Returns if an expression modifies any value. */
        bool isModifyingExpression(SgExpression* exp);
        
        /** Returns if an expression contains any subexpression which modifies any value. */
        bool containsModifyingExpression(SgExpression* exp);

        /** Returns if an expression is an assignment operator (including +=, etc.). */
        bool isAssignmentOp(SgExpression* e);
}

