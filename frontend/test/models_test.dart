import 'package:flutter_test/flutter_test.dart';
import 'package:seatmap_frontend/models/admin_models.dart';
import 'package:seatmap_frontend/models/desk_model.dart';
import 'package:seatmap_frontend/models/seat_model.dart';

void main() {
  group('Modelos do Frontend SeatMap (Unit Tests)', () {
    test('DeskModel deve mapear status de manutenção corretamente', () {
      const desk = DeskModel(
        id: 'desk_1',
        number: '10',
        dx: 100,
        dy: 200,
        width: 38,
        height: 19,
        status: DeskStatus.maintenance,
      );

      expect(desk.isMaintenance, true);
      expect(desk.status, DeskStatus.maintenance);
      expect(desk.isAvailable, false);
    });

    test('CadeiraModel deve serializar e deserializar JSON com campos de manutenção', () {
      final json = {
        'id': 25,
        'identificador': 'Mesa 25',
        'posicao_x': 150,
        'posicao_y': 300,
        'status': 'manutencao',
        'status_operacional': 'EM_MANUTENCAO',
        'motivo_manutencao': 'Falta de ponto de rede',
        'previsao_retorno': '2026-09-08T12:00:00.000Z',
      };

      final cadeira = CadeiraModel.fromJson(json);

      expect(cadeira.id, 25);
      expect(cadeira.identificador, 'Mesa 25');
      expect(cadeira.isManutencao, true);
      expect(cadeira.statusOperacional, 'EM_MANUTENCAO');
      expect(cadeira.motivoManutencao, 'Falta de ponto de rede');
      expect(cadeira.previsaoRetorno, '2026-09-08T12:00:00.000Z');
    });

    test('AdminManutencaoKpisModel deve processar métricas de parque com precisão', () {
      final json = {
        'totalBloqueadas': 4,
        'totalOperacionais': 96,
        'totalAtrasadas': 1,
      };

      final kpis = AdminManutencaoKpisModel.fromJson(json);

      expect(kpis.totalBloqueadas, 4);
      expect(kpis.totalOperacionais, 96);
      expect(kpis.totalAtrasadas, 1);
    });

    test('AdminManutencaoModel deve identificar interdição atrasada corretamente', () {
      final jsonPassada = {
        'id': 1,
        'identificador': 'Mesa 10',
        'status_operacional': 'EM_MANUTENCAO',
        'motivo_manutencao': 'Tomada queimada',
        'previsao_retorno': '2020-01-01T10:00:00.000Z',
        'baia_id': 1,
        'baia_nome': 'Baia A',
        'escritorio_id': 1,
        'escritorio_nome': 'Matriz SP',
        'escritorio_cidade': 'São Paulo',
      };

      final manutencao = AdminManutencaoModel.fromJson(jsonPassada);
      expect(manutencao.isAtrasada, true);
    });
  });
}

