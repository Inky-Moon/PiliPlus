import javassist.ClassPool;
import javassist.CtClass;
import javassist.expr.ExprEditor;
import javassist.expr.MethodCall;

/** Applies the Flutter embedding changes required to run on Android API 23. */
public final class EnginePatcher {
    private static final String OUTPUT_DIRECTORY = System.getProperty("android6.output");

    private EnginePatcher() {}

    public static void main(String[] args) throws Exception {
        if (args.length != 2 || OUTPUT_DIRECTORY == null || OUTPUT_DIRECTORY.isBlank()) {
            throw new IllegalArgumentException(
                    "Usage: java -Dandroid6.output=<dir> EnginePatcher <engine.jar> <android.jar>");
        }

        ClassPool pool = new ClassPool(true);
        pool.insertClassPath(args[0]);
        pool.insertClassPath(args[1]);

        patchLocalization(pool);
        patchAccessibility(pool, "io.flutter.view.AccessibilityBridge");
        patchAccessibility(pool, "io.flutter.view.AccessibilityViewEmbedder");
        patchPathUtils(pool);
        System.out.println("Patched all Android 6 compatibility targets");
    }

    private static void patchLocalization(ClassPool pool) throws Exception {
        CtClass type = pool.get("io.flutter.plugin.localization.LocalizationPlugin");
        type.getDeclaredMethod("resolveNativeLocale").setBody(
                "{ if ($1 == null || $1.isEmpty()) return null; "
                        + "return (java.util.Locale) $1.get(0); }");
        type.getDeclaredMethod("sendLocalesToFlutter").setBody(
                "{ java.util.List locales = new java.util.ArrayList(); "
                        + "locales.add($1.locale); this.localizationChannel.sendLocales(locales); }");
        type.writeFile(OUTPUT_DIRECTORY);
        type.detach();
        System.out.println("Patched LocalizationPlugin");
    }

    private static void patchAccessibility(ClassPool pool, String className) throws Exception {
        CtClass type = pool.get(className);
        int[] replacements = {0};
        type.instrument(new ExprEditor() {
            @Override
            public void edit(MethodCall call) throws javassist.CannotCompileException {
                if (call.getMethodName().equals("setImportantForAccessibility")) {
                    call.replace("{ }");
                    replacements[0]++;
                }
            }
        });
        if (replacements[0] == 0) {
            throw new IllegalStateException("No accessibility calls found in " + className);
        }
        type.writeFile(OUTPUT_DIRECTORY);
        type.detach();
        System.out.println("Patched " + className + " (" + replacements[0] + " calls)");
    }

    private static void patchPathUtils(ClassPool pool) throws Exception {
        CtClass type = pool.get("io.flutter.util.PathUtils");
        int[] replacements = {0};
        type.instrument(new ExprEditor() {
            @Override
            public void edit(MethodCall call) throws javassist.CannotCompileException {
                if (call.getMethodName().equals("getDataDir")
                        && call.getClassName().equals("android.content.Context")) {
                    call.replace(
                            "{ $_ = new java.io.File($0.getApplicationInfo().dataDir); }");
                    replacements[0]++;
                }
            }
        });
        if (replacements[0] == 0) {
            throw new IllegalStateException("No Context.getDataDir call found in PathUtils");
        }
        type.writeFile(OUTPUT_DIRECTORY);
        type.detach();
        System.out.println("Patched PathUtils (" + replacements[0] + " calls)");
    }
}
