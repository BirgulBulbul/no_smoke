
import '../models/task_model.dart';

class TaskEngine {
  static List<TaskModel> generateTasks(int riskScore) {
    if (riskScore >= 80) {
      return [
        const TaskModel(
          title: "İlk sigarayı geciktir",
          description: "İlk sigaranı en az 30 dakika geciktir.",
        ),
        const TaskModel(
          title: "Bir sigarayı atla",
          description: "Bugün içeceğin bir sigarayı atla.",
        ),
        const TaskModel(
          title: "30 dakika sigarasız kal",
          description: "Önümüzdeki 30 dakika sigara içme.",
        ),
        const TaskModel(
          title: "Kriz anını işaretle",
          description: "Canın sigara istediği zamanı kaydet.",
        ),
        const TaskModel(
          title: "Su iç",
          description: "Ekstra 2 bardak su iç.",
        ),
      ];
    }

    if (riskScore >= 60) {
      return [
        const TaskModel(
          title: "İlk sigarayı geciktir",
          description: "İlk sigaranı 45 dakika geciktir.",
        ),
        const TaskModel(
          title: "Bir sigarayı atla",
          description: "Bugün bir sigarayı atla.",
        ),
        const TaskModel(
          title: "45 dakika sigarasız kal",
          description: "45 dakika sigara içme.",
        ),
        const TaskModel(
          title: "Kriz saatini kaydet",
          description: "En zorlandığın saati işaretle.",
        ),
      ];
    }

    if (riskScore >= 40) {
      return [
        const TaskModel(
          title: "60 dakika sigarasız kal",
          description: "1 saat sigara içmeden bekle.",
        ),
        const TaskModel(
          title: "2 sigarayı atla",
          description: "Bugün 2 sigara eksik iç.",
        ),
        const TaskModel(
          title: "Nefes egzersizi",
          description: "3 dakika nefes egzersizi yap.",
        ),
      ];
    }

    if (riskScore >= 20) {
      return [
        const TaskModel(
          title: "2 saat sigarasız kal",
          description: "2 saat boyunca sigara içme.",
        ),
        const TaskModel(
          title: "3 sigara eksilt",
          description: "Bugün 3 sigara daha az iç.",
        ),
      ];
    }

    return [
      const TaskModel(
        title: "4 saat sigarasız kal",
        description: "Bugün 4 saat boyunca sigara içme.",
      ),
    ];
  }
}
