---
title: Spark SQL Catalyst优化器
tags: spark
key: 29
modify_date: 2019-04-30 18:00:00 +08:00
---

记录一下个人对sparkSql的catalyst这个**函数式的可扩展的查询优化器**的理解，

----
# Overview
Spark SQL的核心是Catalyst优化器，是以一种新颖的方式利用Scala的的模式匹配和[quasiquotes](https://github.com/marsishandsome/SparkSQL-Internal/blob/master/06-component/code_generation.md#scala-quasiquotes)机制来构建的可扩展查询优化器。

![image](https://user-images.githubusercontent.com/8369671/80785361-96e12b00-8bb2-11ea-9f20-a1e9cc526dae.png)
> sparkSql pipeline

sparkSql的catalyst优化器是整个sparkSql pipeline的中间核心部分，其执行策略主要两方向，
1. 基于规则优化/Rule Based Optimizer/RBO
    - 一种经验式、启发式优化思路
    - 对于核心优化算子join有点力不从心，如两张表执行join，到底使用broadcaseHashJoin还是sortMergeJoin，目前sparkSql是通过手工设定参数来确定的，如果一个表的数据量小于某个阈值（默认10M？）就使用broadcastHashJoin
        - nestedLoopsJoin，P，Q双表两个大循环, O(M*N)
        - sortMergeJoin是P，Q双表排序后互相游标
        - broadcastHashJoin，PQ双表中小表放入内存hash表，大表遍历O(1)方式取小表内容
2. 基于代价优化/Cost Based Optimizer/CBO
    - 针对每个join评估当前两张表使用每种join策略的代价，根据代价估算确定一种代价最小的方案
    - 不同physical plans输入到[代价模型](https://www.slideshare.net/databricks/costbased-optimizer-in-apache-spark-22)（目前是统计），调整join顺序，减少中间shuffle数据集大小，达到最优输出

----
# Catalyst工作流程
- Parser，利用[ANTLR](https://github.com/antlr/antlr4)将sparkSql字符串解析为抽象语法树AST，称为unresolved logical plan/ULP
- Analyzer，借助于数据元数据catalog将ULP解析为logical plan/LP
- Optimizer，根据各种RBO，CBO优化策略得到optimized logical plan/OLP，主要是对Logical Plan进行剪枝，合并等操作，进而删除掉一些无用计算，或对一些计算的多个步骤进行合并

## other
Optimizer是catalyst工作[最后阶段](https://github.com/ColZer/DigAndBuried/blob/master/spark/spark-catalyst-optimizer.md#spark-catalyst-optimizer)了，后面生成physical plan以及执行，主要是由sparkSql来完成。
- SparkPlanner
   - 优化后的逻辑执行计划OLP依然是逻辑的，并不能被spark系统理解，此时需要将OLP转换成physical plan
   - 从逻辑计划/OLP生成一个或多个物理执行计划，基于成本模型cost model从中选择一个
- Code generation
   - 生成Java bytecode然后在每一台机器上执行，形成RDD graph/DAG

----
# Parser模块
将sparkSql字符串切分成一个一个token，再根据一定语义规则解析为一个抽象语法树/AST。Parser模块目前基本都使用第三方类库ANTLR来实现，比如Hive，presto，sparkSql等。

![image](https://user-images.githubusercontent.com/8369671/80785364-9a74b200-8bb2-11ea-8629-71cccbfa7a38.png)
> parser切词

Spark 1.x版本使用的是Scala原生的[Parser Combinator](http://blog.csdn.net/oopsoom/article/details/37943507)构建词法和语法分析器，而Spark 2.x版本使用的是第三方语法解析器工具ANTLR4。

Spark2.x SQL语句的解析采用的是ANTLR4，ANTLR4根据语法文件[SqlBase.g4](https://github.com/apache/spark/blob/master/sql/catalyst/src/main/antlr4/org/apache/spark/sql/catalyst/parser/SqlBase.g4)自动解析生成两个Java类：**词法**解析器SqlBaseLexer和**语法**解析器SqlBaseParser。

SqlBaseLexer和SqlBaseParser都是使用ANTLR4自动生成的Java类。使用这两个解析器将SQL字符串语句解析成了ANTLR4的ParseTree语法树结构。然后在parsePlan过程中，使用[AstBuilder.scala](https://github.com/apache/spark/blob/master/sql/catalyst/src/main/scala/org/apache/spark/sql/catalyst/parser/AstBuilder.scala)将ParseTree转换成catalyst表达式逻辑计划LogicalPlan。

----
# Analyzer模块
通过解析后ULP有了基本骨架，但是系统对表的字段信息是不知道的。如sum，select，join，where还有score，people都表示什么含义，此时需要基本的`元数据信息schema catalog`来表达这些token。最重要的元数据信息就是，
   - 表的schema信息，主要包括表的基本定义（表名、列名、数据类型）、表的数据格式（json、text、parquet、压缩格式等）、表的物理位置
   - 基本函数信息，主要是指类信息

Analyzer会再次遍历整个AST，对树上的每个节点进行**数据类型绑定**以及**函数绑定**，比如people词素会根据元数据表信息解析为包含age、id以及name三列的表，people.age会被解析为数据类型为int的变量，sum会被解析为特定的聚合函数，

![image](https://user-images.githubusercontent.com/8369671/80785366-9f396600-8bb2-11ea-8c15-04c6de9ff437.png)
> 词义注入

```
//org.apache.spark.sql.catalyst.analysis.Analyzer.scala
  lazy val batches: Seq[Batch] = Seq( //不同Batch代表不同的解析策略
    Batch("Substitution", fixedPoint,
      CTESubstitution,
      WindowsSubstitution,
      EliminateUnions,
      new SubstituteUnresolvedOrdinals(conf)),
    Batch("Resolution", fixedPoint,
      ResolveTableValuedFunctions ::
      ResolveRelations ::  //通过catalog解析表或列基本数据类型,命名等信息
      ResolveReferences :: //解析从子节点的操作生成的属性，一般是别名引起的，比如people.age
      ResolveCreateNamedStruct ::
      ResolveDeserializer ::
      ResolveNewInstance ::
      ResolveUpCast ::
      ResolveGroupingAnalytics ::
      ResolvePivot ::
      ResolveOrdinalInOrderByAndGroupBy ::
      ResolveMissingReferences ::
      ExtractGenerator ::
      ResolveGenerate ::
      ResolveFunctions :: //解析基本函数,如max,min,agg
      ResolveAliases ::
      ResolveSubquery :: //解析AST中的字查询信息
      ResolveWindowOrder ::
      ResolveWindowFrame ::
      ResolveNaturalAndUsingJoin ::
      ExtractWindowExpressions ::
      GlobalAggregates :: //解析全局的聚合函数，比如select sum(score) from table
      ResolveAggregateFunctions ::
      TimeWindowing ::
      ResolveInlineTables ::
      TypeCoercion.typeCoercionRules ++
      extendedResolutionRules : _*),
    Batch("Nondeterministic", Once,
      PullOutNondeterministic),
    Batch("UDF", Once,
      HandleNullInputsForUDF),
    Batch("FixNullability", Once,
      FixNullability),
    Batch("Cleanup", fixedPoint,
      CleanupAliases)
  )
```

----
# Optimizer模块
Optimizer是catalyst的核心，分为RBO和CBO两种。
RBO的优化策略就是对语法树进行一次遍历，模式匹配能够满足特定规则的节点，再进行相应的**等价转换**，即将一棵树等价地转换为另一棵树。SQL中经典的常见优化规则有，
   - 谓词下推（predicate pushdown）
   - 常量累加（constant folding）
   - 列值裁剪（column pruning）
   - Limits合并（combine limits）

![image](https://user-images.githubusercontent.com/8369671/80785373-a2cced00-8bb2-11ea-94b1-cd1afbaa6444.png)
> 由下往上走，从join后再filter优化为filter再join

![image](https://user-images.githubusercontent.com/8369671/80785377-a52f4700-8bb2-11ea-8af3-b1700332ad84.png)
> 从`100+80`优化为`180`，避免每一条record都需要执行一次`100+80`的操作

![image](https://user-images.githubusercontent.com/8369671/80785378-a6f90a80-8bb2-11ea-9af9-e4cc01d6198c.png)
> 剪裁不需要的字段，特别是嵌套里面的不需要字段。如只需people.age，不需要people.address，那么可以将address字段丢弃

```
//@see http://blog.csdn.net/oopsoom/article/details/38121259
//org.apache.spark.sql.catalyst.optimizer.Optimizer.scala
  def batches: Seq[Batch] = {
    // Technically some of the rules in Finish Analysis are not optimizer rules and belong more
    // in the analyzer, because they are needed for correctness (e.g. ComputeCurrentTime).
    // However, because we also use the analyzer to canonicalized queries (for view definition),
    // we do not eliminate subqueries or compute current time in the analyzer.
    Batch("Finish Analysis", Once,
      EliminateSubqueryAliases,
      ReplaceExpressions,
      ComputeCurrentTime,
      GetCurrentDatabase(sessionCatalog),
      RewriteDistinctAggregates) ::
    //////////////////////////////////////////////////////////////////////////////////////////
    // Optimizer rules start here
    //////////////////////////////////////////////////////////////////////////////////////////
    // - Do the first call of CombineUnions before starting the major Optimizer rules,
    //   since it can reduce the number of iteration and the other rules could add/move
    //   extra operators between two adjacent Union operators.
    // - Call CombineUnions again in Batch("Operator Optimizations"),
    //   since the other rules might make two separate Unions operators adjacent.
    Batch("Union", Once,
      CombineUnions) ::
    Batch("Subquery", Once,
      OptimizeSubqueries) ::
    Batch("Replace Operators", fixedPoint,
      ReplaceIntersectWithSemiJoin,
      ReplaceExceptWithAntiJoin,
      ReplaceDistinctWithAggregate) ::
    Batch("Aggregate", fixedPoint,
      RemoveLiteralFromGroupExpressions,
      RemoveRepetitionFromGroupExpressions) ::
    Batch("Operator Optimizations", fixedPoint,
      // Operator push down
      PushProjectionThroughUnion,
      ReorderJoin,
      EliminateOuterJoin,
      PushPredicateThroughJoin, //谓词下推之一
      PushDownPredicate, //谓词下推之一
      LimitPushDown,
      ColumnPruning, //列值剪裁,常用于聚合操作,join左右孩子操作,合并相邻project列
      InferFiltersFromConstraints,
      // Operator combine
      CollapseRepartition,
      CollapseProject,
      CollapseWindow,
      CombineFilters, //谓词下推之一,合并两个相邻的Filter。合并2个节点，就可以减少树的深度从而减少重复执行过滤的代价
      CombineLimits, //合并Limits
      CombineUnions,
      // Constant folding and strength reduction
      NullPropagation,
      FoldablePropagation,
      OptimizeIn(conf),
      ConstantFolding, //常量累加之一
      ReorderAssociativeOperator,
      LikeSimplification,
      BooleanSimplification, //常量累加之一,布尔表达式的提前短路
      SimplifyConditionals,
      RemoveDispensableExpressions,
      SimplifyBinaryComparison,
      PruneFilters,
      EliminateSorts,
      SimplifyCasts,
      SimplifyCaseConversionExpressions,
      RewriteCorrelatedScalarSubquery,
      EliminateSerialization,
      RemoveRedundantAliases,
      RemoveRedundantProject) ::
    Batch("Check Cartesian Products", Once,
      CheckCartesianProducts(conf)) ::
    Batch("Decimal Optimizations", fixedPoint,
      DecimalAggregates) ::
    Batch("Typed Filter Optimization", fixedPoint,
      CombineTypedFilters) ::
    Batch("LocalRelation", fixedPoint,
      ConvertToLocalRelation,
      PropagateEmptyRelation) ::
    Batch("OptimizeCodegen", Once,
      OptimizeCodegen(conf)) ::
    Batch("RewriteSubquery", Once,
      RewritePredicateSubquery,
      CollapseProject) :: Nil
  }
```

----
# SparkPlanner模块
至此，OLP已经得到了比较完善的优化，然而此时OLP依然没有办法真正执行，它们只是逻辑上可行，实际上spark并不知道如何去执行这个OLP。
   - 比如join只是一个抽象概念，代表两个表根据相同的id进行合并，然而具体怎么实现这个合并，逻辑执行计划并没有说明

![image](https://user-images.githubusercontent.com/8369671/80785383-aa8c9180-8bb2-11ea-9c27-325888ae695c.png)
> optimized logical plan -> physical plan

此时就需要将左边的OLP转换为physical plan物理执行计划，将逻辑上可行的执行计划变为spark可以真正执行的计划。
   - 比如join算子，spark根据不同场景为该算子制定了不同的算法策略，有broadcastHashJoin、shuffleHashJoin以及[sortMergeJoin](https://www.iteblog.com/archives/2086.html)，物理执行计划实际上就是在这些具体实现中挑选一个耗时最小的算法实现，这个过程涉及到cost model/[CBO](https://www.slideshare.net/databricks/costbased-optimizer-in-apache-spark-22)

![image](https://user-images.githubusercontent.com/8369671/80785385-aceeeb80-8bb2-11ea-9fb8-fc0be966447a.png)
> CBO off

![image](https://user-images.githubusercontent.com/8369671/80785389-af514580-8bb2-11ea-8d9c-d4e71a6a28a8.png)
> CBO on

CBO中常见的优化是`join换位`，以便尽量减少中间shuffle数据集大小，达到最优输出。

----
# Job UI
![image](https://user-images.githubusercontent.com/8369671/80785395-b2e4cc80-8bb2-11ea-802d-49468b245b2f.png)
> sp.prepare.PrepareController

- [WholeStageCodegen](https://stackoverflow.com/questions/40590028/what-do-the-blue-blocks-in-spark-stage-dag-visualisation-ui-mean)，将多个operators合并成一个java函数，从而提高执行速度
- Project，投影/只取所需列
- Exchange，stage间隔，产生了shuffle

----
# Reference
- [Deep Dive Into Catalyst: Apache Spark’s Optimizer](https://www.slideshare.net/databricks/a-deep-dive-into-spark-sqls-catalyst-optimizer-with-yin-huai)
- [Spark SQL Optimization – Understanding the Catalyst Optimizer](https://data-flair.training/blogs/spark-sql-optimization-catalyst-optimizer/)
- [Catalyst——Spark SQL中的函数式关系查询优化框架](http://www.infoq.com/cn/presentations/functional-relational-query-optimization-framework-of-spark-sql)
- [SparkSQL – 从0到1认识Catalyst](http://hbasefly.com/2017/03/01/sparksql-catalyst/)
- [Spark-Catalyst Optimizer](https://github.com/ColZer/DigAndBuried/blob/master/spark/spark-catalyst-optimizer.md)
- [sparksql执行流程分析](https://www.jianshu.com/p/0aa4b1caac2e)
- [SparkSQL优化器Catalyst](https://www.jianshu.com/p/6e94440aa025)
- [spark catalyst source code](https://github.com/apache/spark/tree/master/sql/catalyst/src/main/scala/org/apache/spark/sql/catalyst)
- [Cost-Based Optimizer in Apache Spark 2.2](https://www.slideshare.net/databricks/costbased-optimizer-in-apache-spark-22)
