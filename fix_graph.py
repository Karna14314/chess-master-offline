with open('lib/screens/analysis/widgets/interactive_eval_graph.dart', 'r') as f:
    content = f.read()

content = content.replace("axisSide: meta.axisSide", "meta: meta")

with open('lib/screens/analysis/widgets/interactive_eval_graph.dart', 'w') as f:
    f.write(content)
